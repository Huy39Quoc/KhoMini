package com.storehub.service.impl;

import com.storehub.dto.request.PaymentConfirmationRequest;
import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;
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
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.EmailService;
import com.storehub.service.PaymentService;
import com.storehub.service.PricingService;
import com.storehub.util.VNPayUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import static com.storehub.common.PaymentNotes.DEPOSIT_REFUND;
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

    // Dòng RENTAL_FEE đi kèm khoản cọc dùng mã giao dịch = mã của dòng DEPOSIT + hậu tố này.
    private static final String RENTAL_SUFFIX = "-R";
    private static final String RENTAL_FEE_REFUND = "RENTAL_FEE_REFUND";

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
    @Transactional
    public PaymentResponse initiatePayment(
            String customerEmail,
            PaymentInitiationRequest request
    ) {
        User customer = userRepository
                .findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        Booking booking = bookingRepository
                .findByIdAndCustomerId(request.getBookingId(), customer.getId())
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
                primaryAmount = pricingService.calculateDepositAmount(
                        facilityId,
                        booking.getTotalRentalFee(),
                        defaultDeposit
                );
                if (primaryAmount == null) {
                    primaryAmount = BigDecimal.ZERO;
                }
                rentalAmount = booking.getTotalRentalFee().add(
                        pricingService.calculateManagementFee(facilityId, booking.getRentalMonths()));
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

        // Thử thanh toán lại: các giao dịch đặt chỗ cũ chưa hoàn tất không còn hiệu lực.
        if (request.getPaymentType() == PaymentType.DEPOSIT) {
            for (Payment stale : paymentRepository.findByBooking_IdAndStatusAndPaymentTypeIn(
                    booking.getId(), PaymentStatus.PENDING,
                    java.util.List.of(PaymentType.DEPOSIT, PaymentType.RENTAL_FEE))) {
                stale.setStatus(PaymentStatus.FAILED);
                paymentRepository.save(stale);
            }
        }

        String transactionId =
                "TXN-"
                        + UUID.randomUUID()
                        .toString()
                        .substring(0, 8)
                        .toUpperCase();

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

    // Giữ endpoint POST /payments/confirm cho tương thích, nhưng KHÔNG còn tự đánh dấu PAID:
    // khách không thể tự xác nhận đã trả tiền. Chỉ trả về trạng thái hiện tại; giao dịch
    // chuyển PAID khi VNPay gọi về processVnpayCallback.
    @Override
    @Transactional(readOnly = true)
    public PaymentResponse confirmPayment(
            String customerEmail,
            PaymentConfirmationRequest request
    ) {
        return getPaymentStatus(customerEmail, request.getTransactionId());
    }

    @Override
    @Transactional
    public PaymentResponse confirmPayment(PaymentConfirmationRequest request) {
        Payment payment = paymentRepository
                .lockByTransactionId(request.getTransactionId())
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

        if (payment.getStatus() == PaymentStatus.PAID) {
            return toPaymentResponse(payment);
        }
        if (payment.getStatus() != PaymentStatus.PENDING) {
            throw new AppException(ErrorCode.PAYMENT_ALREADY_PROCESSED);
        }

        Booking booking = payment.getBooking();

        if (booking == null) {
            throw new AppException(ErrorCode.BOOKING_NOT_FOUND);
        }

        return processPaymentConfirmation(payment, booking);
    }

    private PaymentResponse toPaymentResponse(Payment payment) {
        Booking booking = payment.getBooking();
        User customer = booking != null ? booking.getCustomer() : null;
        StorageUnit unit = booking != null ? booking.getStorageUnit() : null;
        Facility facility = unit != null ? unit.getFacility() : null;

        return PaymentResponse.builder()
                .id(payment.getId())
                .transactionId(payment.getTransactionId())
                .bookingId(booking != null ? booking.getId() : null)
                .bookingCode(booking != null ? booking.getBookingCode() : null)
                .customerName(customer != null ? customer.getFullName() : null)
                .customerEmail(customer != null ? customer.getEmail() : null)
                .facilityName(facility != null ? facility.getName() : null)
                .unitCode(unit != null ? unit.getUnitCode() : null)
                .amount(groupAmount(payment))
                .paymentType(payment.getPaymentType())
                .status(payment.getStatus())
                .refundStatus(payment.getTransactionId() != null
                        && payment.getTransactionId().startsWith("RF-")
                        ? refundRequests.findByRefundPayment_Id(payment.getId())
                            .map(RefundRequest::getStatus).orElse(null) : null)
                .paymentMethod(payment.getPaymentMethod())
                .paymentTime(payment.getPaymentTime())
                .note(payment.getNote())
                .build();
    }

    private PaymentResponse processPaymentConfirmation(Payment payment, Booking booking) {
        if (booking.getExpiresAt() != null
                && booking.getExpiresAt().isBefore(LocalDateTime.now())
                && booking.getStatus() == BookingStatus.PENDING_PAYMENT) {
            throw new AppException(ErrorCode.BOOKING_EXPIRED);
        }

        if (payment.getPaymentType() == PaymentType.DEPOSIT) {
            if (booking.getStatus() != BookingStatus.PENDING_PAYMENT
                    || booking.getStorageUnit() == null
                    || booking.getStorageUnit().getStatus() != UnitStatus.RESERVED) {
                throw new AppException(ErrorCode.UNIT_UNAVAILABLE);
            }
        }

        payment.setStatus(PaymentStatus.PAID);
        payment.setPaymentTime(LocalDateTime.now());
        paymentRepository.save(payment);

        if (payment.getPaymentType() == PaymentType.DEPOSIT) {
            booking.setDepositPaid(
                    booking.getDepositPaid().add(payment.getAmount())
            );
            booking.setStatus(BookingStatus.CONFIRMED);

            // Dòng tiền thuê + phí quản lý đi kèm trong cùng giao dịch VNPay
            paymentRepository.findByTransactionId(payment.getTransactionId() + RENTAL_SUFFIX)
                    .filter(p -> p.getStatus() == PaymentStatus.PENDING)
                    .ifPresent(p -> {
                        p.setStatus(PaymentStatus.PAID);
                        p.setPaymentTime(LocalDateTime.now());
                        paymentRepository.save(p);
                    });
        }

        if (payment.getPaymentType() == PaymentType.EXTRA_CHARGE
                && RENTAL_EXTENSION.equals(payment.getNote())
                && booking.getPendingExtraMonths() != null) {
            var oldEndDate = booking.getEndDate();

            booking.setEndDate(oldEndDate.plusMonths(booking.getPendingExtraMonths()));
            booking.setRentalMonths(booking.getRentalMonths() + booking.getPendingExtraMonths());
            booking.setTotalRentalFee(booking.getTotalRentalFee().add(booking.getPendingExtensionFee()));

            int extendedMonths = booking.getPendingExtraMonths();
            booking.setPendingExtraMonths(null);
            booking.setPendingExtensionFee(null);

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
    @Transactional(readOnly = true)
    public PaymentResponse getPendingExtensionPayment(String customerEmail, UUID bookingId) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        Booking booking = bookingRepository.findByIdAndCustomerId(bookingId, customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        if (booking.getPendingExtraMonths() == null) {
            throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
        }

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

        String vnpayUrl = buildVnpayUrl(payment.getTransactionId(), payment.getAmount());

        return PaymentResponse.builder()
                .id(payment.getId())
                .transactionId(payment.getTransactionId())
                .bookingId(booking.getId())
                .amount(groupAmount(payment))
                .paymentType(payment.getPaymentType())
                .status(payment.getStatus())
                .paymentMethod(payment.getPaymentMethod())
                .paymentUrl(vnpayUrl)
                .qrCodeUrl(vnpayUrl)
                .paymentTime(payment.getPaymentTime())
                .note(payment.getNote())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public PaymentResponse getPendingOverduePayment(
            String customerEmail,
            UUID bookingId
    ) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() ->
                        new AppException(ErrorCode.USER_NOT_FOUND)
                );

        Booking booking = bookingRepository
                .findByIdAndCustomerId(
                        bookingId,
                        customer.getId()
                )
                .orElseThrow(() ->
                        new AppException(ErrorCode.BOOKING_NOT_FOUND)
                );

        Payment payment = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                        bookingId,
                        PaymentType.EXTRA_CHARGE,
                        PaymentStatus.PENDING,
                        OVERDUE_LATE_FEE
                )
                .orElseThrow(() ->
                        new AppException(ErrorCode.PAYMENT_NOT_FOUND)
                );

        String vnpayUrl = buildVnpayUrl(payment.getTransactionId(), payment.getAmount());

        return PaymentResponse.builder()
                .id(payment.getId())
                .transactionId(payment.getTransactionId())
                .bookingId(booking.getId())
                .amount(groupAmount(payment))
                .paymentType(payment.getPaymentType())
                .status(payment.getStatus())
                .paymentMethod(payment.getPaymentMethod())
                .note(payment.getNote())
                .paymentUrl(vnpayUrl)
                .qrCodeUrl(vnpayUrl)
                .paymentTime(payment.getPaymentTime())
                .build();
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
            // Đối chiếu số tiền VNPay báo về với số tiền của giao dịch (chỉ khi còn PENDING,
            // để IPN/return gọi lặp lại vẫn idempotent).
            Payment pending = paymentRepository.findByTransactionId(transactionId)
                    .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
            if (pending.getStatus() == PaymentStatus.PENDING) {
                pending.setGatewayTransactionNo(queryParams.get("vnp_TransactionNo"));
            }
            if (pending.getStatus() == PaymentStatus.PENDING) {
                long expected = groupAmount(pending).multiply(new BigDecimal(100)).longValue();
                long actual;
                try {
                    actual = Long.parseLong(queryParams.get("vnp_Amount"));
                } catch (NumberFormatException e) {
                    log.error("VNPay callback has invalid vnp_Amount for {}", transactionId);
                    throw new AppException(ErrorCode.INVALID_REQUEST);
                }
                if (actual != expected) {
                    log.error("VNPay amount mismatch for {}: expected {}, got {}", transactionId, expected, actual);
                    throw new AppException(ErrorCode.INVALID_REQUEST);
                }
            }
            PaymentConfirmationRequest confirmationRequest = new PaymentConfirmationRequest();
            confirmationRequest.setTransactionId(transactionId);
            return confirmPayment(confirmationRequest);
        } else {
            log.warn("VNPay payment failed or cancelled with response code: {}, transaction status: {} for transactionId: {}",
                    responseCode, transactionStatus, transactionId);
            Payment payment = paymentRepository.lockByTransactionId(transactionId)
                    .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

            BigDecimal payableAmount = groupAmount(payment);
            if (payment.getStatus() == PaymentStatus.PENDING) {
                payment.setStatus(PaymentStatus.FAILED);
                paymentRepository.save(payment);

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

    // Số tiền hiển thị/đối chiếu của một giao dịch: với dòng DEPOSIT chính của đợt đặt chỗ thì là
    // tổng (cọc + tiền thuê + phí quản lý) đã gửi sang VNPay; các loại khác giữ nguyên.
    private BigDecimal groupAmount(Payment payment) {
        if (payment.getPaymentType() == PaymentType.DEPOSIT
                && payment.getTransactionId() != null
                && payment.getTransactionId().startsWith("TXN-")
                && (payment.getStatus() == PaymentStatus.PENDING
                || payment.getStatus() == PaymentStatus.PAID
                || payment.getStatus() == PaymentStatus.FAILED)) {
            return paymentRepository.findByTransactionId(payment.getTransactionId() + RENTAL_SUFFIX)
                    .filter(p -> p.getStatus() == payment.getStatus())
                    .map(p -> payment.getAmount().add(p.getAmount()))
                    .orElse(payment.getAmount());
        }
        return payment.getAmount();
    }

    @Override
    @Transactional
    public BigDecimal refundOnCancellation(Booking booking) {
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
                booking.getStorageUnit().getFacility().getId(),
                depositPaid.add(rentPaid),
                booking.getStartDate().atStartOfDay(),
                LocalDateTime.now());
        if (refundTotal.signum() <= 0) {
            return BigDecimal.ZERO;
        }

        BigDecimal depositPart = refundTotal.min(depositPaid);
        BigDecimal rentalPart = refundTotal.subtract(depositPart).min(rentPaid);
        return queueRefund(booking, depositPart, rentalPart);
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
        if (refundRequests.existsByBooking_Id(booking.getId())) {
            throw new AppException(ErrorCode.PAYMENT_ALREADY_PROCESSED);
        }
        Payment original = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                        booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
        String requestId = UUID.randomUUID().toString().replace("-", "").toUpperCase();
        Payment refundPayment = paymentRepository.save(Payment.builder()
                .transactionId("RF-" + requestId)
                .booking(booking)
                .amount(total)
                .paymentType(PaymentType.DEPOSIT)
                .status(PaymentStatus.REFUND_PENDING)
                .paymentMethod(original.getPaymentMethod())
                .note(DEPOSIT_REFUND)
                .paymentTime(LocalDateTime.now())
                .build());
        refundRequests.save(RefundRequest.builder()
                .booking(booking).originalPayment(original).refundPayment(refundPayment)
                .requestId(requestId).amount(total).depositAmount(depositPart)
                .rentalAmount(rentalPart)
                .status(original.getGatewayCreateDate() == null
                        ? RefundStatus.MISSING_METADATA : RefundStatus.QUEUED)
                .updatedStatusAt(LocalDateTime.now())
                .build());
        return total;
    }

    @Override
    @Transactional
    public BigDecimal refundDepositOnReturn(Booking booking) {
        Payment lateFee = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                        booking.getId(),
                        PaymentType.EXTRA_CHARGE,
                        PaymentStatus.PENDING,
                        OVERDUE_LATE_FEE
                )
                .orElse(null);

        if (lateFee != null
                && lateFee.getAmount() != null
                && lateFee.getAmount().signum() > 0) {
            throw new AppException(ErrorCode.OVERDUE_FEE_UNPAID_ON_RETURN);
        }

        if (booking.getPendingExtraMonths() != null) {
            paymentRepository
                    .findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                            booking.getId(),
                            PaymentType.EXTRA_CHARGE,
                            PaymentStatus.PENDING,
                            RENTAL_EXTENSION
                    )
                    .ifPresent(payment -> {
                        payment.setStatus(PaymentStatus.FAILED);
                        paymentRepository.save(payment);
                    });
            booking.setPendingExtraMonths(null);
            booking.setPendingExtensionFee(null);
        }

        return refundDeposit(booking, booking.getDepositPaid());
    }

    @Override
    @Transactional(readOnly = true)
    public List<PaymentResponse> getMyPaymentHistory(String customerEmail) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        return paymentRepository.findCustomerPayments(customer.getId())
                .stream()
                .map(this::toPaymentResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<PaymentResponse> getFacilityPaymentHistory(String userEmail, UUID facilityId) {
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
        return paymentRepository.findFacilityPayments(facilityId)
                .stream()
                .map(this::toPaymentResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<PaymentResponse> getAllPaymentHistory() {
        return paymentRepository.findAllPayments()
                .stream()
                .map(this::toPaymentResponse)
                .toList();
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
