package com.storehub.service.impl;

import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.common.PageResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.User;
import java.util.List;
import com.storehub.enums.ActivityAction;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.enums.RefundStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.exception.OutstandingOverdueExtensionException;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.scheduler.OverdueScheduler;
import com.storehub.service.ActivityLogService;
import com.storehub.service.EmailService;
import com.storehub.service.PaymentService;
import com.storehub.service.PricingService;
import com.storehub.service.WaitlistService;
import com.storehub.util.VNPayUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.data.domain.Pageable;
import org.springframework.transaction.annotation.Transactional;

import static com.storehub.common.PaymentNotes.DEPOSIT_REFUND;
import static com.storehub.common.PaymentNotes.EXTRA_CHARGE_REFUND;
import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import static com.storehub.common.PaymentNotes.RENTAL_EXTENSION;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PaymentServiceImpl implements PaymentService {

    private final PaymentRepository paymentRepository;
    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final EmailService emailService;
    private final ActivityLogService activityLogService;
    private final PricingService pricingService;
    private final RefundRequestRepository refundRequests;
    private final FacilityPolicyRepository facilityPolicies;
    private final VnpayRefundClient gateway;
    private final WaitlistService waitlistService;
    private final OverdueScheduler overdueScheduler;
    private final com.storehub.repository.DepositDeductionRepository depositDeductions;

    // Dòng RENTAL_FEE đi kèm khoản cọc dùng mã giao dịch = mã của dòng DEPOSIT + hậu tố này.
    private static final String RENTAL_SUFFIX = "-R";
    private static final String RENTAL_FEE_REFUND = "RENTAL_FEE_REFUND";
    private static final DateTimeFormatter VNP_DATE = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    @Value("${vnpay.tmn-code}")
    private String vnpTmnCode;

    @Value("${vnpay.hash-secret}")
    private String vnpHashSecret;

    @Value("${vnpay.url}")
    private String vnpUrl;

    @Value("${vnpay.return-url}")
    private String vnpReturnUrl;

    @Value("${vnpay.merchant-ip}")
    private String vnpMerchantIp;

    @Override
    @Transactional(noRollbackFor = OutstandingOverdueExtensionException.class)
    public PaymentResponse initiatePayment(
            String customerEmail,
            PaymentInitiationRequest request
    ) {
        User customer = userRepository
                .findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        Booking booking = bookingRepository
                .lockByIdAndCustomerId(request.getBookingId(), customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        if (booking.getExpiresAt() != null
                && booking.getExpiresAt().isBefore(LocalDateTime.now())
                && booking.getStatus() == BookingStatus.PENDING_PAYMENT) {
            throw new AppException(ErrorCode.BOOKING_EXPIRED);
        }

        if (booking.getStorageUnit() == null
                || booking.getStorageUnit().getUnitType() == null) {
            throw new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND);
        }

        PaymentType requestedType = request.getPaymentType();
        if ((requestedType == PaymentType.DEPOSIT || requestedType == PaymentType.RENTAL_FEE)
                && booking.getStatus() != BookingStatus.PENDING_PAYMENT) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        if (requestedType == PaymentType.EXTRA_CHARGE
                && booking.getStatus() != BookingStatus.ACTIVE) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        if (requestedType == PaymentType.EXTRA_CHARGE) {
            blockExtensionIfOverdue(booking);
        }

        if (requestedType == PaymentType.DEPOSIT) {
            List<Payment> pending = paymentRepository.findByBooking_IdAndStatusAndPaymentTypeIn(
                    booking.getId(), PaymentStatus.PENDING,
                    List.of(PaymentType.DEPOSIT, PaymentType.RENTAL_FEE));
            if (!pending.isEmpty()) {
                return reusePendingDeposit(booking, pending);
            }
        }

        UUID facilityId = (booking.getStorageUnit() != null && booking.getStorageUnit().getFacility() != null)
                ? booking.getStorageUnit().getFacility().getId()
                : null;
        BigDecimal defaultDeposit = (booking.getStorageUnit() != null && booking.getStorageUnit().getUnitType() != null)
                ? booking.getStorageUnit().getUnitType().getDepositAmount()
                : BigDecimal.ZERO;

        // Đặt chỗ: MỘT lần thanh toán VNPay thu cả tiền cọc (hoàn lại khi trả kho) lẫn tiền thuê + phí quản lý
        // (doanh thu). Hai khoản được ghi thành 2 dòng Payment: DEPOSIT (dòng chính, mã giao dịch gửi VNPay)
        // và RENTAL_FEE (mã = mã chính + "-R"), cùng chuyển PAID khi VNPay báo thành công.
        BigDecimal payableAmount;
        BigDecimal primaryAmount;
        BigDecimal rentalAmount = BigDecimal.ZERO;

        switch (request.getPaymentType()) {
            case DEPOSIT -> {
                primaryAmount = booking.getQuotedDepositAmount() != null
                        ? booking.getQuotedDepositAmount()
                        : pricingService.calculateDepositAmount(
                                facilityId,
                                booking.getTotalRentalFee(),
                                defaultDeposit
                        );
                if (primaryAmount == null) {
                    primaryAmount = BigDecimal.ZERO;
                }
                BigDecimal managementFee = booking.getQuotedManagementFee() != null
                        ? booking.getQuotedManagementFee()
                        : pricingService.calculateManagementFee(facilityId, booking.getRentalMonths());
                rentalAmount = booking.getTotalRentalFee().add(managementFee);
                payableAmount = primaryAmount.add(rentalAmount);
            }
            case EXTRA_CHARGE -> {
                if (booking.getPendingExtensionFee() == null) {
                    throw new AppException(ErrorCode.INVALID_REQUEST);
                }
                primaryAmount = booking.getPendingExtensionFee();
                payableAmount = primaryAmount;
            }
            // RENTAL_FEE không được khởi tạo riêng: nó được thu cùng lúc với cọc khi đặt chỗ.
            default -> throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        if (payableAmount == null
                || payableAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        String transactionId = newTransactionId();

        LocalDateTime initiatedAt = LocalDateTime.now(java.time.ZoneId.of("Asia/Ho_Chi_Minh"));
        Payment payment = Payment.builder()
                .transactionId(transactionId)
                .booking(booking)
                .amount(primaryAmount)
                .paymentType(request.getPaymentType())
                .status(PaymentStatus.PENDING)
                .paymentMethod(request.getPaymentMethod())
                .note(request.getPaymentType() == PaymentType.EXTRA_CHARGE
                        ? RENTAL_EXTENSION
                        : null)
                .paymentTime(LocalDateTime.now())
                .gatewayCreateDate(initiatedAt.format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss")))
                .gatewayAmount(payableAmount)
                .build();

        Payment savedPayment = paymentRepository.save(payment);

        if (rentalAmount.signum() > 0) {
            paymentRepository.save(Payment.builder()
                    .transactionId(transactionId + RENTAL_SUFFIX)
                    .booking(booking)
                    .amount(rentalAmount)
                    .paymentType(PaymentType.RENTAL_FEE)
                    .status(PaymentStatus.PENDING)
                    .paymentMethod(request.getPaymentMethod())
                    .paymentTime(LocalDateTime.now())
                    .build());
        }
        String vnpayUrl = buildVnpayUrl(transactionId, payableAmount, initiatedAt);

        return PaymentResponse.builder()
                .id(savedPayment.getId())
                .transactionId(savedPayment.getTransactionId())
                .bookingId(booking.getId())
                .amount(payableAmount)
                .paymentType(savedPayment.getPaymentType())
                .status(savedPayment.getStatus())
                .paymentMethod(savedPayment.getPaymentMethod())
                .paymentUrl(vnpayUrl)
                .qrCodeUrl(vnpayUrl)
                .paymentTime(savedPayment.getPaymentTime())
                .note(payment.getNote())
                .build();
    }

    private PaymentResponse reusePendingDeposit(Booking booking, List<Payment> pending) {
        List<Payment> primaries = pending.stream()
                .filter(p -> p.getPaymentType() == PaymentType.DEPOSIT).toList();
        if (primaries.size() != 1) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        Payment primary = primaries.get(0);
        if (primary.getGatewayAmount() == null || primary.getGatewayCreateDate() == null
                || pending.stream().anyMatch(p -> p != primary &&
                        !((primary.getTransactionId() + RENTAL_SUFFIX).equals(p.getTransactionId())
                                && p.getPaymentType() == PaymentType.RENTAL_FEE))
                || primary.getGatewayAmount().compareTo(pending.stream()
                        .map(Payment::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add)) != 0) {
            // Legacy or inconsistent attempts must be reconciled before opening a new payment.
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        LocalDateTime created;
        try {
            created = LocalDateTime.parse(primary.getGatewayCreateDate(), VNP_DATE);
        } catch (java.time.format.DateTimeParseException ex) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        Payment rental = pending.stream()
                .filter(p -> p.getPaymentType() == PaymentType.RENTAL_FEE).findFirst().orElse(null);
        return resolveAttempt(booking, primary, rental, created);
    }

    private PaymentResponse resolveAttempt(Booking booking, Payment primary, Payment rental,
                                           LocalDateTime created) {
        if (created.plusMinutes(15).isAfter(LocalDateTime.now(java.time.ZoneId.of("Asia/Ho_Chi_Minh")))) {
            return paymentLink(booking, primary, created);
        }
        VnpayRefundClient.GatewayResult result;
        try {
            result = gateway.query(primary.getTransactionId(), primary.getGatewayCreateDate());
        } catch (Exception ex) {
            log.warn("VNPay transaction {} must be reconciled before retry: {}",
                    primary.getTransactionId(), ex.toString());
            throw new AppException(ErrorCode.PAYMENT_RECONCILIATION_PENDING);
        }
        if (result.confirmedCharge(primary.getGatewayAmount())) {
            return settleVerifiedCharge(primary.getTransactionId(), result.transactionNo(), result.amount());
        }
        // A signed QueryDr answer indicating failure or no transaction permits a
        // new TxnRef. Any future successful IPN for the old TxnRef is still accepted;
        // only the first charge activates the booking, later charges are refunded.
        boolean retryable = "91".equals(result.responseCode())
                || ("00".equals(result.responseCode()) && "02".equals(result.transactionStatus()));
        if (!retryable) {
            throw new AppException(ErrorCode.PAYMENT_RECONCILIATION_PENDING);
        }
        if (primary.getPaymentType() == PaymentType.DEPOSIT
                && booking.getExpiresAt() != null
                && !booking.getExpiresAt().isAfter(LocalDateTime.now())) {
            throw new AppException(ErrorCode.BOOKING_EXPIRED);
        }
        if (primary.getPaymentType() == PaymentType.EXTRA_CHARGE) {
            primary.setVoidedAt(LocalDateTime.now());
        }
        primary.setStatus(PaymentStatus.FAILED);
        paymentRepository.save(primary);
        if (rental != null) {
            rental.setStatus(PaymentStatus.FAILED);
            paymentRepository.save(rental);
        }
        String transactionId = newTransactionId();
        LocalDateTime now = LocalDateTime.now(java.time.ZoneId.of("Asia/Ho_Chi_Minh"));
        Payment replacement = Payment.builder()
                .transactionId(transactionId).booking(booking).amount(primary.getAmount())
                .paymentType(primary.getPaymentType()).status(PaymentStatus.PENDING)
                .paymentMethod(primary.getPaymentMethod()).note(primary.getNote())
                .paymentTime(primary.getPaymentType() == PaymentType.EXTRA_CHARGE
                        ? primary.getPaymentTime() : LocalDateTime.now())
                .gatewayAmount(primary.getGatewayAmount())
                .gatewayCreateDate(now.format(VNP_DATE)).build();
        paymentRepository.save(replacement);
        if (rental != null) {
            paymentRepository.save(Payment.builder()
                    .transactionId(transactionId + RENTAL_SUFFIX).booking(booking)
                    .amount(rental.getAmount()).paymentType(PaymentType.RENTAL_FEE)
                    .status(PaymentStatus.PENDING).paymentMethod(rental.getPaymentMethod())
                    .paymentTime(LocalDateTime.now()).build());
        }
        return paymentLink(booking, replacement, now);
    }

    private PaymentResponse paymentLink(Booking booking, Payment primary, LocalDateTime created) {
        String url = buildVnpayUrl(primary.getTransactionId(), primary.getGatewayAmount(), created);
        return PaymentResponse.builder()
                .id(primary.getId())
                .transactionId(primary.getTransactionId())
                .bookingId(booking.getId())
                .amount(primary.getGatewayAmount())
                .paymentType(primary.getPaymentType())
                .status(primary.getStatus())
                .paymentMethod(primary.getPaymentMethod())
                .paymentUrl(url)
                .qrCodeUrl(url)
                .paymentTime(primary.getPaymentTime())
                .note(primary.getNote())
                .build();
    }

    private String newTransactionId() {
        return "TXN-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }

    private String buildVnpayUrl(String transactionId, BigDecimal amount) {
        return buildVnpayUrl(transactionId, amount,
                LocalDateTime.now(java.time.ZoneId.of("Asia/Ho_Chi_Minh")));
    }

    private String buildVnpayUrl(String transactionId, BigDecimal amount, LocalDateTime now) {
        long vnpAmount = amount.multiply(new BigDecimal(100)).longValue();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

        Map<String, String> vnpParams = new HashMap<>();
        vnpParams.put("vnp_Version", "2.1.0");
        vnpParams.put("vnp_Command", "pay");
        vnpParams.put("vnp_TmnCode", vnpTmnCode);
        vnpParams.put("vnp_Amount", String.valueOf(vnpAmount));
        vnpParams.put("vnp_CurrCode", "VND");
        vnpParams.put("vnp_TxnRef", transactionId);
        vnpParams.put("vnp_OrderInfo", "Thanh toan StoreHub order " + transactionId);
        vnpParams.put("vnp_OrderType", "other");
        vnpParams.put("vnp_Locale", "vn");
        vnpParams.put("vnp_ReturnUrl", vnpReturnUrl);
        vnpParams.put("vnp_IpAddr", vnpMerchantIp);
        vnpParams.put("vnp_CreateDate", now.format(formatter));
        vnpParams.put("vnp_ExpireDate", now.plusMinutes(15).format(formatter));

        return VNPayUtil.buildPaymentUrl(vnpParams, vnpHashSecret, vnpUrl);
    }

    @Override
    @Transactional(readOnly = true)
    public PaymentResponse getPaymentStatus(String customerEmail, String transactionId) {
        Payment payment = paymentRepository.findByTransactionId(transactionId)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

        Booking booking = payment.getBooking();
        if (booking == null || booking.getCustomer() == null
                || customerEmail == null
                || !customerEmail.equalsIgnoreCase(booking.getCustomer().getEmail())) {
            throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
        }
        return toPaymentResponse(payment);
    }

    /**
     * Một khoản thu cọc/thuê VNPay quá hạn mà cổng thanh toán xác nhận "không có giao dịch" hoặc
     * "giao dịch lỗi" là khoản bị bỏ dở (khách đóng app, lỗi mạng...). Chuyển sang FAILED để lịch sử
     * giao dịch không còn "Pending" vĩnh viễn. Nếu VNPay báo thành công muộn thì đối soát vẫn xử lý
     * được vì reconcile chấp nhận cả PENDING lẫn FAILED. Kết quả không chắc chắn thì giữ nguyên.
     */
    @Transactional
    public void expireAbandonedCharge(String transactionId, VnpayRefundClient.GatewayResult result) {
        boolean definitelyUnpaid = "91".equals(result.responseCode())
                || ("00".equals(result.responseCode()) && "02".equals(result.transactionStatus()));
        if (!definitelyUnpaid) {
            return;
        }
        Payment payment = paymentRepository.lockByTransactionId(transactionId).orElse(null);
        if (payment == null || payment.getStatus() != PaymentStatus.PENDING
                || payment.getPaymentType() != PaymentType.DEPOSIT) {
            return;
        }
        payment.setStatus(PaymentStatus.FAILED);
        paymentRepository.save(payment);
        paymentRepository.findByTransactionId(transactionId + RENTAL_SUFFIX)
                .filter(companion -> companion.getStatus() == PaymentStatus.PENDING)
                .ifPresent(companion -> {
                    companion.setStatus(PaymentStatus.FAILED);
                    paymentRepository.save(companion);
                });
    }

    @Transactional
    public PaymentResponse reconcileConfirmedCharge(String transactionId,
                                                     VnpayRefundClient.GatewayResult result) {
        Payment payment = paymentRepository.findByTransactionId(transactionId)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
        if (payment.getGatewayAmount() == null
                || !result.confirmedCharge(payment.getGatewayAmount())) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        return settleVerifiedCharge(transactionId, result.transactionNo(), result.amount());
    }

    private PaymentResponse settleVerifiedCharge(String transactionId, String gatewayTxnNo,
                                                 String gatewayAmount) {
        UUID bookingId = paymentRepository.findBookingIdByTransactionId(transactionId)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
        // All booking status transitions (callback, cancel, expiry) take this lock first.
        Booking booking = bookingRepository.lockById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));
        Payment payment = paymentRepository.lockByTransactionId(transactionId)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

        if (gatewayAmount != null) {
            BigDecimal expected = payment.getGatewayAmount() != null
                    ? payment.getGatewayAmount() : groupAmount(payment);
            try {
                if (gatewayAmount.isBlank()
                        || new BigDecimal(gatewayAmount).compareTo(expected.movePointRight(2)) != 0) {
                    throw new AppException(ErrorCode.INVALID_REQUEST);
                }
            } catch (NumberFormatException e) {
                throw new AppException(ErrorCode.INVALID_REQUEST);
            }
        }
        if (payment.getStatus() == PaymentStatus.PAID
                || payment.getStatus() == PaymentStatus.REFUND_PENDING
                || payment.getStatus() == PaymentStatus.REFUNDED) {
            return toPaymentResponse(payment);
        }
        if (payment.getStatus() != PaymentStatus.PENDING && payment.getStatus() != PaymentStatus.FAILED) {
            throw new AppException(ErrorCode.PAYMENT_ALREADY_PROCESSED);
        }
        if (gatewayTxnNo != null && !gatewayTxnNo.isBlank()) {
            payment.setGatewayTransactionNo(gatewayTxnNo);
        }
        return processPaymentConfirmation(payment, booking);
    }

    private PaymentResponse toPaymentResponse(Payment payment) {
        Booking booking = payment.getBooking();
        User customer = booking != null ? booking.getCustomer() : null;
        StorageUnit unit = booking != null ? booking.getStorageUnit() : null;
        Facility facility = unit != null ? unit.getFacility() : null;

        Payment companion = (payment.getTransactionId() != null && payment.getTransactionId().startsWith("TXN-"))
                ? paymentRepository.findByTransactionId(payment.getTransactionId() + RENTAL_SUFFIX).orElse(null)
                : null;
        BigDecimal displayAmount = companion != null ? payment.getAmount().add(companion.getAmount()) : payment.getAmount();
        PaymentStatus displayStatus = payment.getStatus();
        if (displayStatus == PaymentStatus.REFUNDED && companion != null && companion.getStatus() == PaymentStatus.PAID) {
            displayStatus = PaymentStatus.PAID;
        }

        BigDecimal rentalFee = null;
        BigDecimal managementFee = null;
        BigDecimal depositAmount = null;
        BigDecimal damageDeduction = null;
        BigDecimal refundedAmount = null;

        if (payment.getTransactionId() != null && payment.getTransactionId().startsWith("RF-")) {
            RefundRequest refund = refundRequests.findByRefundPayment_Id(payment.getId()).orElse(null);
            if (refund != null) {
                damageDeduction = refund.getDamageDeduction();
                refundedAmount = refund.getAmount();
                rentalFee = refund.getRentalAmount();
                if (refund.getOriginalPayment() != null && refund.getOriginalPayment().getAmount() != null) {
                    depositAmount = refund.getOriginalPayment().getAmount();
                } else if (refund.getDepositAmount() != null) {
                    depositAmount = refund.getDepositAmount().add(damageDeduction != null ? damageDeduction : BigDecimal.ZERO);
                } else {
                    depositAmount = refund.getAmount().add(damageDeduction != null ? damageDeduction : BigDecimal.ZERO);
                }
            }
        } else if (booking != null && companion != null) {
            rentalFee = booking.getTotalRentalFee();
            managementFee = booking.getQuotedManagementFee();
            depositAmount = booking.getQuotedDepositAmount();
            refundedAmount = refundRequests.findByOriginalPayment_Id(payment.getId())
                    .filter(r -> r.getStatus() == com.storehub.enums.RefundStatus.COMPLETED)
                    .map(RefundRequest::getAmount)
                    .orElse(null);
        }

        return PaymentResponse.builder()
                .id(payment.getId())
                .transactionId(payment.getTransactionId())
                .bookingId(booking != null ? booking.getId() : null)
                .bookingCode(booking != null ? booking.getBookingCode() : null)
                .customerName(customer != null ? customer.getFullName() : null)
                .customerEmail(customer != null ? customer.getEmail() : null)
                .facilityName(facility != null ? facility.getName() : null)
                .unitCode(unit != null && booking != null
                        && Boolean.TRUE.equals(booking.getUnitAssignmentConfirmed())
                        ? unit.getUnitCode() : null)
                .amount(displayAmount)
                .paymentType(payment.getPaymentType())
                .status(displayStatus)
                .refundStatus(payment.getTransactionId() != null
                        && payment.getTransactionId().startsWith("RF-")
                        ? refundRequests.findByRefundPayment_Id(payment.getId())
                            .map(RefundRequest::getStatus).orElse(null)
                        : refundRequests.findByOriginalPayment_Id(payment.getId())
                            .map(RefundRequest::getStatus).orElse(null))
                .paymentMethod(payment.getPaymentMethod())
                .paymentTime(payment.getPaymentTime())
                .note(payment.getNote())
                .rentalFee(rentalFee)
                .managementFee(managementFee)
                .depositAmount(depositAmount)
                .damageDeduction(damageDeduction)
                .refundedAmount(refundedAmount)
                .build();
    }

    private PaymentResponse processPaymentConfirmation(Payment payment, Booking booking) {
        boolean expired = booking.getExpiresAt() != null
                && booking.getExpiresAt().isBefore(LocalDateTime.now());
        boolean lateDeposit = false;
        if (payment.getPaymentType() == PaymentType.DEPOSIT) {
            lateDeposit = expired || booking.getStatus() != BookingStatus.PENDING_PAYMENT
                    || booking.getStorageUnit() == null
                    || booking.getStorageUnit().getStatus() != UnitStatus.RESERVED;
        }

        payment.setStatus(PaymentStatus.PAID);
        payment.setPaymentTime(LocalDateTime.now());
        paymentRepository.save(payment);

        if (payment.getPaymentType() == PaymentType.EXTRA_CHARGE
                && payment.getVoidedAt() != null) {
            queueRefund(booking, payment, BigDecimal.ZERO, payment.getAmount());
            payment.setStatus(PaymentStatus.REFUND_PENDING);
            return toPaymentResponse(payment);
        }

        if (payment.getPaymentType() == PaymentType.DEPOSIT) {
            booking.setDepositPaid(booking.getDepositPaid().add(payment.getAmount()));
            // Dòng tiền thuê + phí quản lý đi kèm trong cùng giao dịch VNPay
            Payment rental = paymentRepository.findByTransactionId(payment.getTransactionId() + RENTAL_SUFFIX)
                    .orElse(null);
            BigDecimal rentalAmount = rental != null ? rental.getAmount() : BigDecimal.ZERO;
            if (payment.getGatewayAmount() == null) {
                // Older attempts did not persist the gateway amount. A signed
                // callback has already been compared to these two ledger rows.
                payment.setGatewayAmount(payment.getAmount().add(rentalAmount));
            }
            if ((payment.getGatewayAmount() != null
                    && payment.getGatewayAmount().compareTo(payment.getAmount().add(rentalAmount)) != 0)
                    || (rental != null && rental.getStatus() != PaymentStatus.PENDING
                        && rental.getStatus() != PaymentStatus.FAILED)) {
                throw new AppException(ErrorCode.INVALID_REQUEST);
            }
            if (rental != null) {
                rental.setStatus(PaymentStatus.PAID);
                rental.setPaymentTime(payment.getPaymentTime());
                paymentRepository.save(rental);
            }

            if (lateDeposit) {
                if (booking.getStatus() == BookingStatus.PENDING_PAYMENT) {
                    booking.setStatus(BookingStatus.CANCELLED);
                    if (booking.getStorageUnit() != null
                            && booking.getStorageUnit().getStatus() == UnitStatus.RESERVED) {
                        booking.getStorageUnit().setStatus(UnitStatus.AVAILABLE);
                    }
                }
                // The gateway captured money even though this booking cannot be
                // handed over. Refund the FULL original charge, not just the deposit.
                queueRefund(booking, payment, payment.getAmount(), rentalAmount);
                payment.setStatus(PaymentStatus.REFUND_PENDING);
                if (rental != null) rental.setStatus(PaymentStatus.REFUND_PENDING);
                bookingRepository.save(booking);
                return toPaymentResponse(payment);
            }
            booking.setStatus(BookingStatus.CONFIRMED);
            if (booking.getCustomer() != null && booking.getStorageUnit() != null
                    && booking.getStorageUnit().getFacility() != null
                    && booking.getStorageUnit().getUnitType() != null) {
                waitlistService.markFulfilled(booking.getCustomer().getId(),
                        booking.getStorageUnit().getFacility().getId(),
                        booking.getStorageUnit().getUnitType().getId());
            }
        }

        if (payment.getPaymentType() == PaymentType.EXTRA_CHARGE
                && RENTAL_EXTENSION.equals(payment.getNote())) {
            if (payment.getVoidedAt() != null || booking.getStatus() != BookingStatus.ACTIVE
                    || booking.getPendingExtraMonths() == null
                    || booking.getPendingExtensionFee() == null
                    || booking.getPendingExtensionFee().compareTo(payment.getAmount()) != 0) {
                // Cancellation/return does not revoke an already opened VNPay URL.
                // A captured charge belongs to this attempt and must be refunded.
                queueRefund(booking, payment, BigDecimal.ZERO, payment.getAmount());
                payment.setStatus(PaymentStatus.REFUND_PENDING);
                return toPaymentResponse(payment);
            }
            // A payment URL may have been issued before expiry and captured after
            // the nightly fee job was missed. Accrue under the same booking lock.
            // Refund this charge instead of extending while the debt is unpaid.
            if (overdueScheduler.accrueOutstandingForCheckout(booking, LocalDateTime.now())) {
                paymentRepository.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                                booking.getId(), PaymentType.EXTRA_CHARGE, RENTAL_EXTENSION,
                                List.of(PaymentStatus.PENDING, PaymentStatus.FAILED))
                        .stream().filter(attempt -> !attempt.getTransactionId()
                                .equals(payment.getTransactionId()))
                        .forEach(attempt -> {
                            attempt.setVoidedAt(LocalDateTime.now());
                            attempt.setStatus(PaymentStatus.FAILED);
                            paymentRepository.save(attempt);
                        });
                booking.setPendingExtraMonths(null);
                booking.setPendingExtensionFee(null);
                bookingRepository.save(booking);
                queueRefund(booking, payment, BigDecimal.ZERO, payment.getAmount());
                payment.setStatus(PaymentStatus.REFUND_PENDING);
                return toPaymentResponse(payment);
            }
            var oldEndDate = booking.getEndDate();

            booking.setEndDate(oldEndDate.plusMonths(booking.getPendingExtraMonths()));
            booking.setRentalMonths(booking.getRentalMonths() + booking.getPendingExtraMonths());
            booking.setTotalRentalFee(booking.getTotalRentalFee().add(booking.getPendingExtensionFee()));

            int extendedMonths = booking.getPendingExtraMonths();
            booking.setPendingExtraMonths(null);
            booking.setPendingExtensionFee(null);

            com.storehub.common.OverdueRecovery.restore(booking, activityLogService);

            activityLogService.record(
                    ActivityAction.CONTRACT_EXTENDED,
                    "BOOKING",
                    booking.getId(),
                    "Extended booking " + booking.getBookingCode() + " by " + extendedMonths
                            + " month(s) after extension fee payment " + payment.getTransactionId()
                            + " (old end date: " + oldEndDate + ", new end date: " + booking.getEndDate() + ")",
                    oldEndDate,
                    booking.getEndDate()
            );
        }

        bookingRepository.save(booking);

        if (payment.getPaymentType() == PaymentType.DEPOSIT
                && booking.getStatus() == BookingStatus.CONFIRMED) {
            try {
                User customer = booking.getCustomer();
                var unit = booking.getStorageUnit();
                var facility = unit != null ? unit.getFacility() : null;

                emailService.sendBookingConfirmationEmail(
                        customer.getEmail(),
                        customer.getFullName(),
                        booking.getBookingCode(),
                        facility != null ? facility.getName() : "–",
                        unit != null ? unit.getUnitCode() : "–",
                        booking.getStartDate(),
                        booking.getEndDate(),
                        groupAmount(payment)
                );
            } catch (Exception e) {
                log.warn("Failed to send booking confirmation email for booking {}: {}",
                        booking.getId(), e.getMessage());
            }
        }

        return PaymentResponse.builder()
                .id(payment.getId())
                .transactionId(payment.getTransactionId())
                .bookingId(booking.getId())
                .amount(groupAmount(payment))
                .paymentType(payment.getPaymentType())
                .status(payment.getStatus())
                .paymentMethod(payment.getPaymentMethod())
                .paymentTime(payment.getPaymentTime())
                .note(payment.getNote())
                .build();
    }

    @Override
    @Transactional(noRollbackFor = OutstandingOverdueExtensionException.class)
    public PaymentResponse getPendingExtensionPayment(String customerEmail, UUID bookingId) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        Booking booking = bookingRepository.lockByIdAndCustomerId(bookingId, customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        if (booking.getPendingExtraMonths() == null) {
            throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
        }

        blockExtensionIfOverdue(booking);

        Payment payment = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                        bookingId,
                        PaymentType.EXTRA_CHARGE,
                        PaymentStatus.PENDING,
                        RENTAL_EXTENSION
                )
                .orElseThrow(() ->
                        new AppException(ErrorCode.PAYMENT_NOT_FOUND)
                );

        return resolveExtraAttempt(booking, payment);
    }

    private void blockExtensionIfOverdue(Booking booking) {
        if (booking.getStatus() == BookingStatus.ACTIVE
                && overdueScheduler.accrueOutstandingForCheckout(booking, LocalDateTime.now())) {
            throw new OutstandingOverdueExtensionException();
        }
    }

    @Override
    @Transactional
    public PaymentResponse getPendingOverduePayment(
            String customerEmail,
            UUID bookingId
    ) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() ->
                        new AppException(ErrorCode.USER_NOT_FOUND)
                );

        Booking booking = bookingRepository
                .lockByIdAndCustomerId(
                        bookingId,
                        customer.getId()
                )
                .orElseThrow(() ->
                        new AppException(ErrorCode.BOOKING_NOT_FOUND)
                );

        // Repair FAILED charges from before automatic retries, while holding the booking lock.
        paymentRepository.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                        bookingId, PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                        List.of(PaymentStatus.FAILED))
                .stream().filter(p -> p.getVoidedAt() == null && p.getAmount() != null
                        && p.getAmount().signum() > 0)
                .forEach(this::replaceFailedLateFee);

        List<Payment> pending = paymentRepository
                .findByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeAsc(
                        bookingId, PaymentType.EXTRA_CHARGE, PaymentStatus.PENDING, OVERDUE_LATE_FEE)
                .stream().filter(p -> p.getAmount() != null && p.getAmount().signum() > 0).toList();
        if (pending.isEmpty()) throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
        PaymentResponse resolved = null;
        for (Payment payment : pending) {
            resolved = resolveExtraAttempt(booking, payment);
            if (resolved.getStatus() != PaymentStatus.PAID) return resolved;
        }
        return resolved;
    }

    private PaymentResponse resolveExtraAttempt(Booking booking, Payment payment) {
        if (payment.getGatewayCreateDate() == null) {
            LocalDateTime now = LocalDateTime.now(java.time.ZoneId.of("Asia/Ho_Chi_Minh"));
            payment.setGatewayCreateDate(now.format(VNP_DATE));
            payment.setGatewayAmount(payment.getAmount());
            paymentRepository.save(payment);
            return paymentLink(booking, payment, now);
        }
        if (payment.getGatewayAmount() == null
                || payment.getGatewayAmount().compareTo(payment.getAmount()) != 0) {
            throw new AppException(ErrorCode.PAYMENT_RECONCILIATION_PENDING);
        }
        try {
            return resolveAttempt(booking, payment, null,
                    LocalDateTime.parse(payment.getGatewayCreateDate(), VNP_DATE));
        } catch (java.time.format.DateTimeParseException ex) {
            throw new AppException(ErrorCode.PAYMENT_RECONCILIATION_PENDING);
        }
    }

    @Override
    @Transactional
    public PaymentResponse processVnpayCallback(Map<String, String> queryParams) {
        boolean isValid = VNPayUtil.verifyCallback(queryParams, vnpHashSecret);
        if (!isValid) {
            log.error("VNPay callback checksum verification failed!");
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        String responseCode = queryParams.get("vnp_ResponseCode");
        String transactionStatus = queryParams.get("vnp_TransactionStatus");
        String transactionId = queryParams.get("vnp_TxnRef");

        if ("00".equals(responseCode) && "01".equals(transactionStatus)) {
            // VNPay has not finished the transaction. Keep it pending for a later IPN.
            Payment payment = paymentRepository.findByTransactionId(transactionId)
                    .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
            return toPaymentResponse(payment);
        }

        if ("00".equals(responseCode) && "00".equals(transactionStatus)) {
            if (queryParams.get("vnp_Amount") == null) {
                throw new AppException(ErrorCode.INVALID_REQUEST);
            }
            // Verify amount under the same booking/payment locks used to settle.
            return settleVerifiedCharge(transactionId,
                    queryParams.get("vnp_TransactionNo"), queryParams.get("vnp_Amount"));
        } else {
            log.warn("VNPay payment failed or cancelled with response code: {}, transaction status: {} for transactionId: {}",
                    responseCode, transactionStatus, transactionId);
            Payment payment = paymentRepository.lockByTransactionId(transactionId)
                    .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

            BigDecimal payableAmount = groupAmount(payment);
            if (payment.getStatus() == PaymentStatus.PENDING) {
                payment.setStatus(PaymentStatus.FAILED);
                paymentRepository.save(payment);

                if (payment.getPaymentType() == PaymentType.EXTRA_CHARGE
                        && OVERDUE_LATE_FEE.equals(payment.getNote())) {
                    replaceFailedLateFee(payment);
                }

                if (payment.getPaymentType() == PaymentType.DEPOSIT) {
                    paymentRepository.findByTransactionId(transactionId + RENTAL_SUFFIX)
                            .filter(companion -> companion.getStatus() == PaymentStatus.PENDING)
                            .ifPresent(companion -> {
                                companion.setStatus(PaymentStatus.FAILED);
                                paymentRepository.save(companion);
                            });
                }
            }

            return PaymentResponse.builder()
                    .id(payment.getId())
                    .transactionId(payment.getTransactionId())
                    .bookingId(payment.getBooking() != null ? payment.getBooking().getId() : null)
                    .amount(payableAmount)
                    .paymentType(payment.getPaymentType())
                    .status(payment.getStatus())
                    .paymentMethod(payment.getPaymentMethod())
                    .paymentTime(payment.getPaymentTime())
                    .note(payment.getNote())
                    .build();
        }
    }

    private Payment replaceFailedLateFee(Payment failed) {
        failed.setVoidedAt(LocalDateTime.now());
        paymentRepository.save(failed);
        return paymentRepository.save(Payment.builder()
                .transactionId(newTransactionId())
                .booking(failed.getBooking())
                .amount(failed.getAmount())
                .paymentType(PaymentType.EXTRA_CHARGE)
                .status(PaymentStatus.PENDING)
                .paymentMethod(failed.getPaymentMethod())
                .note(OVERDUE_LATE_FEE)
                .paymentTime(failed.getPaymentTime())
                .build());
    }

    // Số tiền hiển thị/đối chiếu của một giao dịch: với dòng DEPOSIT chính của đợt đặt chỗ thì là
    // tổng (cọc + tiền thuê + phí quản lý) đã gửi sang VNPay; các loại khác giữ nguyên.
    private BigDecimal groupAmount(Payment payment) {
        if (payment.getPaymentType() == PaymentType.DEPOSIT
                && payment.getTransactionId() != null
                && payment.getTransactionId().startsWith("TXN-")) {
            return paymentRepository.findByTransactionId(payment.getTransactionId() + RENTAL_SUFFIX)
                    .map(p -> payment.getAmount().add(p.getAmount()))
                    .orElse(payment.getAmount());
        }
        return payment.getAmount();
    }

    @Override
    @Transactional
    public BigDecimal refundOnCancellation(Booking booking) {
        if (booking.getHandoverIssueReportedAt() != null && booking.getHandoverTime() == null) {
            return refundForFacilityFailure(booking);
        }
        if (booking.getStorageUnit() == null || booking.getStorageUnit().getFacility() == null) {
            return BigDecimal.ZERO;
        }
        BigDecimal depositPaid = booking.getDepositPaid() != null ? booking.getDepositPaid() : BigDecimal.ZERO;
        Payment rent = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                        booking.getId(), PaymentType.RENTAL_FEE, PaymentStatus.PAID)
                .orElse(null);
        BigDecimal rentPaid = rent != null ? rent.getAmount() : BigDecimal.ZERO;

        BigDecimal refundTotal = pricingService.calculateCancellationRefund(
                booking,
                depositPaid.add(rentPaid),
                booking.getScheduledCheckInTime() != null
                        ? booking.getScheduledCheckInTime()
                        : booking.getStartDate().atStartOfDay(),
                LocalDateTime.now());
        BigDecimal depositPart = refundTotal.max(BigDecimal.ZERO).min(depositPaid);
        BigDecimal rentalPart = refundTotal.subtract(depositPart).min(rentPaid);
        BigDecimal retained = depositPaid.subtract(depositPart);
        if (retained.signum() > 0) {
            Payment original = paymentRepository
                    .findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                            booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID)
                    .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
            recordDepositDeduction(booking, original, retained, "CANCELLATION", "Deposit retained under cancellation policy");
        }
        if (refundTotal.signum() <= 0) return BigDecimal.ZERO;
        return queueRefund(booking, depositPart, rentalPart);
    }

    @Override
    @Transactional
    public BigDecimal refundForFacilityFailure(Booking booking) {
        if (booking.getStatus() != BookingStatus.CONFIRMED || booking.getHandoverTime() != null
                || booking.getHandedOverByStaffId() != null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        Payment original = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                        booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
        // Other late-captured attempts can already have their own pending refunds.
        // Refund only this original charge, never the booking's aggregated deposit.
        BigDecimal deposit = original.getAmount();
        if (deposit == null || deposit.signum() < 0 || booking.getDepositPaid() == null
                || deposit.compareTo(booking.getDepositPaid()) > 0) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        BigDecimal rent = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                        booking.getId(), PaymentType.RENTAL_FEE, PaymentStatus.PAID)
                .map(Payment::getAmount).orElse(BigDecimal.ZERO);
        // Rental payment includes prepaid management fees. Never retain a deposit
        // or apply the customer's cancellation percentages for a facility failure.
        return queueRefund(booking, original, deposit, rent);
    }

    @Override
    @Transactional
    public BigDecimal refundDeposit(Booking booking, BigDecimal refundAmount) {
        BigDecimal deposit = booking.getDepositPaid() != null
                ? booking.getDepositPaid()
                : BigDecimal.ZERO;

        if (deposit.signum() <= 0
                || refundAmount == null
                || refundAmount.signum() <= 0) {
            return BigDecimal.ZERO;
        }

        return queueRefund(booking, refundAmount.min(deposit), BigDecimal.ZERO);
    }

    private BigDecimal queueRefund(Booking booking, BigDecimal depositPart, BigDecimal rentalPart) {
        BigDecimal total = depositPart.add(rentalPart);
        if (total.signum() <= 0) return BigDecimal.ZERO;
        Payment original = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                        booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
        // An extension charge may already have its own refund on this booking.
        // The overload below checks the original charge, which is the actual
        // idempotency key for a refund request.
        return queueRefund(booking, original, depositPart, rentalPart);
    }

    // Multiple captured payment attempts can belong to the same cancelled
    // booking. Each original gateway transaction is refunded at most once.
    private BigDecimal queueRefund(Booking booking, Payment original,
                                   BigDecimal depositPart, BigDecimal rentalPart) {
        return queueRefund(booking, original, depositPart, rentalPart, BigDecimal.ZERO);
    }

    private BigDecimal queueRefund(Booking booking, Payment original,
                                   BigDecimal depositPart, BigDecimal rentalPart,
                                   BigDecimal damageDeduction) {
        BigDecimal total = depositPart.add(rentalPart);
        if (total.signum() <= 0) return BigDecimal.ZERO;
        if (refundRequests.existsByOriginalPayment_Id(original.getId())) {
            throw new AppException(ErrorCode.PAYMENT_ALREADY_PROCESSED);
        }
        String requestId = UUID.randomUUID().toString().replace("-", "").toUpperCase();
        LocalDateTime requestedAt = LocalDateTime.now();
        Integer slaDays = booking.getStorageUnit() != null
                && booking.getStorageUnit().getFacility() != null
                ? facilityPolicies.findByFacility_Id(booking.getStorageUnit().getFacility().getId())
                    .map(policy -> policy.getDepositRefundSlaDays()).orElse(5)
                : 5;
        if (slaDays == null || slaDays < 0) slaDays = 5;

        boolean hasBankInfo = booking.getRefundAccountNumber() != null && !booking.getRefundAccountNumber().isBlank();
        RefundStatus initialStatus = hasBankInfo
                ? RefundStatus.AWAITING_BANK_TRANSFER
                : (original.getGatewayCreateDate() == null
                        ? RefundStatus.MISSING_METADATA : RefundStatus.QUEUED);

        Payment refundPayment = paymentRepository.save(Payment.builder()
                .transactionId("RF-" + requestId)
                .booking(booking)
                .amount(total)
                .paymentType(original.getPaymentType())
                .status(PaymentStatus.REFUND_PENDING)
                .paymentMethod(hasBankInfo ? "BANK_TRANSFER" : original.getPaymentMethod())
                .note(original.getPaymentType() == PaymentType.EXTRA_CHARGE
                        ? EXTRA_CHARGE_REFUND
                        : (DEPOSIT_REFUND + (damageDeduction != null && damageDeduction.signum() > 0
                            ? " (Khấu trừ hư hại: " + damageDeduction.toPlainString() + " ₫)" : "")))
                .paymentTime(requestedAt)
                .build());

        refundRequests.save(RefundRequest.builder()
                .booking(booking).originalPayment(original).refundPayment(refundPayment)
                .requestId(requestId).amount(total).depositAmount(depositPart)
                .rentalAmount(rentalPart)
                .damageDeduction(damageDeduction != null ? damageDeduction : BigDecimal.ZERO)
                .bankCode(booking.getRefundBankCode())
                .bankAccountNumber(booking.getRefundAccountNumber())
                .bankAccountName(booking.getRefundAccountName())
                .status(initialStatus)
                .updatedStatusAt(requestedAt)
                .dueAt(requestedAt.plusDays(slaDays))
                .build());
        return total;
    }

    @Override
    @Transactional
    public BigDecimal refundDepositOnReturn(Booking booking) {
        return refundDepositOnReturn(booking, BigDecimal.ZERO, null);
    }

    @Override
    @Transactional
    public BigDecimal refundDepositOnReturn(Booking booking, BigDecimal damageFee, String damageReason) {
        boolean unpaidLateFee = paymentRepository
                .findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                        booking.getId(), PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                        List.of(PaymentStatus.PENDING, PaymentStatus.FAILED))
                .stream().anyMatch(p -> p.getVoidedAt() == null
                        && p.getAmount() != null && p.getAmount().signum() > 0);
        if (unpaidLateFee) {
            throw new AppException(ErrorCode.OVERDUE_FEE_UNPAID_ON_RETURN);
        }

        if (booking.getPendingExtraMonths() != null) {
            paymentRepository.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                            booking.getId(), PaymentType.EXTRA_CHARGE, RENTAL_EXTENSION,
                            List.of(PaymentStatus.PENDING, PaymentStatus.FAILED))
                    .forEach(payment -> {
                        payment.setVoidedAt(LocalDateTime.now());
                        payment.setStatus(PaymentStatus.FAILED);
                        paymentRepository.save(payment);
                    });
            booking.setPendingExtraMonths(null);
            booking.setPendingExtensionFee(null);
        }

        BigDecimal depositPaid = booking.getDepositPaid() != null ? booking.getDepositPaid() : BigDecimal.ZERO;
        if (damageFee != null && damageFee.signum() < 0) {
            throw new AppException(ErrorCode.DAMAGE_FEE_EXCEEDS_DEPOSIT);
        }
        BigDecimal safeDamage = (damageFee != null && damageFee.signum() > 0) ? damageFee : BigDecimal.ZERO;
        if (safeDamage.signum() > 0 && (damageReason == null || damageReason.isBlank())) {
            throw new AppException(ErrorCode.DAMAGE_REASON_REQUIRED);
        }
        BigDecimal netRefund = depositPaid.subtract(safeDamage);

        if (netRefund.signum() < 0) {
            // Không tạo khoản nợ treo: phí hư hại chỉ được trừ trong phạm vi tiền cọc.
            throw new AppException(ErrorCode.DAMAGE_FEE_EXCEEDS_DEPOSIT);
        }

        if (depositPaid.signum() == 0) {
            return BigDecimal.ZERO;
        }

        Payment original = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                        booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

        if (safeDamage.signum() > 0) {
            recordDepositDeduction(booking, original, safeDamage, "DAMAGE", damageReason);
        }
        if (netRefund.signum() == 0) return BigDecimal.ZERO;
        return queueRefund(booking, original, netRefund, BigDecimal.ZERO, safeDamage);
    }

    private void recordDepositDeduction(Booking booking, Payment original, BigDecimal amount,
                                        String type, String reason) {
        // Cancellation and checkout hold the booking lock. A unique source payment
        // also prevents duplicate deposit conversions if an operation is retried.
        if (depositDeductions.existsByOriginalPayment_Id(original.getId())
                || refundRequests.existsByOriginalPayment_Id(original.getId())) {
            throw new AppException(ErrorCode.PAYMENT_ALREADY_PROCESSED);
        }
        if (amount.compareTo(booking.getDepositPaid()) > 0 || amount.compareTo(original.getAmount()) > 0) {
            throw new AppException(ErrorCode.DAMAGE_FEE_EXCEEDS_DEPOSIT);
        }
        depositDeductions.save(com.storehub.entity.DepositDeduction.builder()
                .booking(booking).originalPayment(original).amount(amount).deductionType(type)
                .reason(reason).recordedAt(LocalDateTime.now()).build());
        booking.setDepositPaid(booking.getDepositPaid().subtract(amount));
        bookingRepository.save(booking);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PaymentResponse> getMyPaymentHistory(String customerEmail, Pageable pageable) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        return PageResponse.from(paymentRepository.findCustomerPayments(customer.getId(), pageable)
                .map(this::toPaymentResponse));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PaymentResponse> getFacilityPaymentHistory(
            String userEmail, UUID facilityId, Pageable pageable) {
        User viewer = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        String role = viewer.getRole() == null || viewer.getRole().getName() == null
                ? "" : viewer.getRole().getName().toUpperCase(Locale.ROOT);
        if (!"ADMIN".equals(role) && !"BUSINESS_MANAGER".equals(role)) {
            if (!"STAFF".equals(role) && !"FACILITY_MANAGER".equals(role)) {
                throw new AppException(ErrorCode.FORBIDDEN);
            }
            if (facilityId == null || viewer.getFacility() == null
                    || !facilityId.equals(viewer.getFacility().getId())) {
                throw new AppException(ErrorCode.FORBIDDEN);
            }
        }
        return PageResponse.from(paymentRepository.findFacilityPayments(facilityId, pageable)
                .map(this::toPaymentResponse));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PaymentResponse> getAllPaymentHistory(Pageable pageable) {
        return PageResponse.from(paymentRepository.findAllPayments(pageable)
                .map(this::toPaymentResponse));
    }

    @Override
    @Transactional(readOnly = true)
    public PaymentResponse getPaymentDetail(UUID paymentId, String userEmail) {
        Payment payment = paymentRepository.findById(paymentId)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

        User user = userRepository.findByEmail(userEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        String role = user.getRole() == null || user.getRole().getName() == null
                ? "" : user.getRole().getName().toUpperCase(Locale.ROOT);
        Booking booking = payment.getBooking();
        switch (role) {
            case "CUSTOMER" -> {
                if (booking == null || booking.getCustomer() == null
                        || !user.getId().equals(booking.getCustomer().getId())) {
                    throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
                }
            }
            case "STAFF", "FACILITY_MANAGER" -> {
                if (user.getFacility() == null || booking == null
                        || booking.getStorageUnit() == null
                        || booking.getStorageUnit().getFacility() == null
                        || !user.getFacility().getId().equals(
                        booking.getStorageUnit().getFacility().getId())) {
                    throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
                }
            }
            case "ADMIN", "BUSINESS_MANAGER" -> { }
            default -> throw new AppException(ErrorCode.FORBIDDEN);
        }

        return toPaymentResponse(payment);
    }
}
