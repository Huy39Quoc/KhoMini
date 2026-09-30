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
import com.storehub.service.PricingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import static com.storehub.common.PaymentNotes.DEPOSIT_REFUND;
import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import static com.storehub.common.PaymentNotes.RENTAL_EXTENSION;
import java.math.BigDecimal;
import java.time.LocalDateTime;
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
            // Cọc/tiền thuê chỉ thu khi đơn đang chờ thanh toán
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        if (requestedType == PaymentType.EXTRA_CHARGE
                && booking.getStatus() != BookingStatus.ACTIVE) {
            // Phí gia hạn chỉ áp dụng cho kho đang sử dụng
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        BigDecimal payableAmount;

        switch (request.getPaymentType()) {
            // Dung cung nguon tinh coc voi luc bao gia (PricingService.calculateDepositAmount)
            // de tien coc thu thuc te khong bi lech so voi so da bao gia cho khach.
            case DEPOSIT -> payableAmount = pricingService.calculateDepositAmount(
                    booking.getStorageUnit().getFacility().getId(),
                    booking.getTotalRentalFee(),
                    booking.getStorageUnit().getUnitType().getDepositAmount()
            );
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

        return PaymentResponse.builder()
                .id(savedPayment.getId())
                .transactionId(savedPayment.getTransactionId())
                .bookingId(booking.getId())
                .amount(savedPayment.getAmount())
                .paymentType(savedPayment.getPaymentType())
                .status(savedPayment.getStatus())
                .paymentMethod(savedPayment.getPaymentMethod())
                .qrCodeUrl(buildQrCodeUrl(transactionId, payableAmount))
                .paymentTime(savedPayment.getPaymentTime())
                .note(payment.getNote())
                .build();
    }

    private String buildQrCodeUrl(String transactionId, BigDecimal amount) {
        return String.format(
                "https://img.vietqr.io/image/"
                        + "970422-STOREHUB-%s.png"
                        + "?amount=%s&addInfo=%s",
                "compact2",
                amount.toPlainString(),
                transactionId
        );
    }

    @Override
    @Transactional
    public PaymentResponse confirmPayment(
            String customerEmail,
            PaymentConfirmationRequest request
    ) {
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

        // Chỉ chủ của giao dịch mới được xác nhận thanh toán (tránh user khác
        // biết transactionId rồi xác nhận hộ / phá giao dịch của người khác).
        if (booking.getCustomer() == null
                || customerEmail == null
                || !customerEmail.equalsIgnoreCase(booking.getCustomer().getEmail())) {
            throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
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

        return PaymentResponse.builder()
                .id(payment.getId())
                .transactionId(payment.getTransactionId())
                .bookingId(booking.getId())
                .amount(payment.getAmount())
                .paymentType(payment.getPaymentType())
                .status(payment.getStatus())
                .paymentMethod(payment.getPaymentMethod())
                .qrCodeUrl(buildQrCodeUrl(payment.getTransactionId(), payment.getAmount()))
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

        return PaymentResponse.builder()
                .id(payment.getId())
                .transactionId(payment.getTransactionId())
                .bookingId(booking.getId())
                .amount(payment.getAmount())
                .paymentType(payment.getPaymentType())
                .status(payment.getStatus())
                .paymentMethod(payment.getPaymentMethod())
                .note(payment.getNote())
                .qrCodeUrl(buildQrCodeUrl(
                        payment.getTransactionId(),
                        payment.getAmount()
                ))
                .paymentTime(payment.getPaymentTime())
                .build();
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

        BigDecimal refund = refundAmount.min(deposit);
        BigDecimal retained = deposit.subtract(refund);

        Payment original = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                        booking.getId(),
                        PaymentType.DEPOSIT,
                        PaymentStatus.PAID
                )
                .orElse(null);

        if (original != null) {
            if (retained.signum() == 0) {
                original.setStatus(PaymentStatus.REFUNDED);
                original.setNote(DEPOSIT_REFUND);
            } else {
                original.setAmount(retained);
                paymentRepository.save(Payment.builder()
                        .transactionId("RF-" + UUID.randomUUID()
                                .toString()
                                .replace("-", "")
                                .substring(0, 12)
                                .toUpperCase())
                        .booking(booking)
                        .amount(refund)
                        .paymentType(PaymentType.DEPOSIT)
                        .status(PaymentStatus.REFUNDED)
                        .paymentMethod(original.getPaymentMethod())
                        .note(DEPOSIT_REFUND)
                        .paymentTime(LocalDateTime.now())
                        .build());
            }
            paymentRepository.save(original);
        }

        booking.setDepositPaid(retained);
        bookingRepository.save(booking);

        activityLogService.recordSystem(
                ActivityAction.REFUND_PROCESSED,
                "BOOKING",
                booking.getId(),
                "Refunded deposit " + refund.toPlainString() + " for booking "
                        + booking.getBookingCode()
                        + (retained.signum() > 0
                        ? " (retained " + retained.toPlainString() + ")"
                        : "")
        );

        return refund;
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
}
