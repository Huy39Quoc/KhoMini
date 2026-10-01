package com.storehub.service.impl;

import com.storehub.dto.request.PaymentConfirmationRequest;
import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.enums.UnitStatus;
import com.storehub.enums.ActivityAction;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.EmailService;
import com.storehub.service.PaymentService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import com.storehub.util.VNPayUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import static com.storehub.common.PaymentNotes.RENTAL_EXTENSION;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
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

    @Value("${vnpay.tmn-code}")
    private String vnpTmnCode;

    @Value("${vnpay.hash-secret}")
    private String vnpHashSecret;

    @Value("${vnpay.url}")
    private String vnpUrl;

    @Value("${vnpay.return-url}")
    private String vnpReturnUrl;

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

        BigDecimal payableAmount;

        switch (request.getPaymentType()) {
            case DEPOSIT -> payableAmount = booking
                    .getStorageUnit()
                    .getUnitType()
                    .getDepositAmount();
            case RENTAL_FEE -> payableAmount = booking.getTotalRentalFee();
            case EXTRA_CHARGE -> {
                if (booking.getPendingExtensionFee() == null) {
                    throw new AppException(ErrorCode.INVALID_REQUEST);
                }
                payableAmount = booking.getPendingExtensionFee();
            }
            default -> throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        if (payableAmount == null
                || payableAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        String transactionId =
                "TXN-"
                        + UUID.randomUUID()
                        .toString()
                        .substring(0, 8)
                        .toUpperCase();

        Payment payment = Payment.builder()
                .transactionId(transactionId)
                .booking(booking)
                .amount(payableAmount)
                .paymentType(request.getPaymentType())
                .status(PaymentStatus.PENDING)
                .paymentMethod(request.getPaymentMethod())
                .note(request.getPaymentType() == PaymentType.EXTRA_CHARGE
                        ? RENTAL_EXTENSION
                        : null)
                .paymentTime(LocalDateTime.now())
                .build();

        Payment savedPayment = paymentRepository.save(payment);
        String vnpayUrl = buildVnpayUrl(transactionId, payableAmount);

        return PaymentResponse.builder()
                .id(savedPayment.getId())
                .transactionId(savedPayment.getTransactionId())
                .bookingId(booking.getId())
                .amount(savedPayment.getAmount())
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
        long vnpAmount = amount.multiply(new BigDecimal(100)).longValue();
        LocalDateTime now = LocalDateTime.now();
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
        vnpParams.put("vnp_IpAddr", "127.0.0.1");
        vnpParams.put("vnp_CreateDate", now.format(formatter));
        vnpParams.put("vnp_ExpireDate", now.plusMinutes(15).format(formatter));

        return VNPayUtil.buildPaymentUrl(vnpParams, vnpHashSecret, vnpUrl);
    }

    @Override
    @Transactional
    public PaymentResponse confirmPayment(PaymentConfirmationRequest request) {
        Payment payment = paymentRepository
                .lockByTransactionId(request.getTransactionId())
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

        if (payment.getStatus() != PaymentStatus.PENDING) {
            throw new AppException(ErrorCode.PAYMENT_ALREADY_PROCESSED);
        }

        Booking booking = payment.getBooking();

        if (booking == null) {
            throw new AppException(ErrorCode.BOOKING_NOT_FOUND);
        }

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
                        payment.getAmount().add(booking.getTotalRentalFee())
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
                .amount(payment.getAmount())
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
                .amount(payment.getAmount())
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
                .amount(payment.getAmount())
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
        String transactionId = queryParams.get("vnp_TxnRef");

        if ("00".equals(responseCode)) {
            PaymentConfirmationRequest confirmationRequest = new PaymentConfirmationRequest();
            confirmationRequest.setTransactionId(transactionId);
            return confirmPayment(confirmationRequest);
        } else {
            log.warn("VNPay payment failed or cancelled with response code: {} for transactionId: {}", responseCode, transactionId);
            Payment payment = paymentRepository.findByTransactionId(transactionId)
                    .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

            if (payment.getStatus() == PaymentStatus.PENDING) {
                payment.setStatus(PaymentStatus.FAILED);
                paymentRepository.save(payment);
            }

            return PaymentResponse.builder()
                    .id(payment.getId())
                    .transactionId(payment.getTransactionId())
                    .bookingId(payment.getBooking() != null ? payment.getBooking().getId() : null)
                    .amount(payment.getAmount())
                    .paymentType(payment.getPaymentType())
                    .status(payment.getStatus())
                    .paymentMethod(payment.getPaymentMethod())
                    .paymentTime(payment.getPaymentTime())
                    .note(payment.getNote())
                    .build();
        }
    }
}