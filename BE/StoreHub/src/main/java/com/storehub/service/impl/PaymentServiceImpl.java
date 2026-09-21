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
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.PaymentService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class PaymentServiceImpl
        implements PaymentService {

    private final PaymentRepository paymentRepository;
    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;

    @Override
    @Transactional
    public PaymentResponse initiatePayment(
            String customerEmail,
            PaymentInitiationRequest request
    ) {
        User customer = userRepository
                .findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(
                        ErrorCode.USER_NOT_FOUND
                ));

        Booking booking = bookingRepository
                .findByIdAndCustomerId(
                        request.getBookingId(),
                        customer.getId()
                )
                .orElseThrow(() -> new AppException(
                        ErrorCode.BOOKING_NOT_FOUND
                ));

        if (booking.getStorageUnit() == null
                || booking.getStorageUnit().getUnitType() == null) {
            throw new AppException(
                    ErrorCode.STORAGE_UNIT_NOT_FOUND
            );
        }

        BigDecimal payableAmount;

        if (request.getPaymentType() == PaymentType.DEPOSIT) {
            payableAmount = booking
                    .getStorageUnit()
                    .getUnitType()
                    .getDepositAmount();
        } else {
            payableAmount = booking.getTotalRentalFee();
        }

        if (payableAmount == null
                || payableAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new AppException(
                    ErrorCode.INVALID_REQUEST
            );
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
                .paymentTime(LocalDateTime.now())
                .build();

        Payment savedPayment =
                paymentRepository.save(payment);

        String qrCodeUrl = String.format(
                "https://img.vietqr.io/image/"
                        + "970422-STOREHUB-%s.png"
                        + "?amount=%s&addInfo=%s",
                "compact2",
                payableAmount.toPlainString(),
                transactionId
        );

        return PaymentResponse.builder()
                .id(savedPayment.getId())
                .transactionId(savedPayment.getTransactionId())
                .bookingId(booking.getId())
                .amount(savedPayment.getAmount())
                .paymentType(savedPayment.getPaymentType())
                .status(savedPayment.getStatus())
                .paymentMethod(savedPayment.getPaymentMethod())
                .qrCodeUrl(qrCodeUrl)
                .paymentTime(savedPayment.getPaymentTime())
                .build();
    }

    @Override
    @Transactional
    public PaymentResponse confirmPayment(
            PaymentConfirmationRequest request
    ) {
        Payment payment = paymentRepository
                .lockByTransactionId(
                        request.getTransactionId()
                )
                .orElseThrow(() -> new AppException(
                        ErrorCode.PAYMENT_NOT_FOUND
                ));

        if (payment.getStatus() != PaymentStatus.PENDING) {
            throw new AppException(
                    ErrorCode.PAYMENT_ALREADY_PROCESSED
            );
        }

        Booking booking = payment.getBooking();

        if (booking == null) {
            throw new AppException(
                    ErrorCode.BOOKING_NOT_FOUND
            );
        }

        /*
         * Tiền cọc chỉ hợp lệ khi:
         * - booking đang chờ thanh toán
         * - unit vẫn đang RESERVED
         */
        if (payment.getPaymentType() == PaymentType.DEPOSIT) {
            if (booking.getStatus() != BookingStatus.PENDING_PAYMENT
                    || booking.getStorageUnit() == null
                    || booking.getStorageUnit().getStatus()
                    != UnitStatus.RESERVED) {
                throw new AppException(
                        ErrorCode.UNIT_UNAVAILABLE
                );
            }
        }

        payment.setStatus(PaymentStatus.PAID);
        payment.setPaymentTime(LocalDateTime.now());

        paymentRepository.save(payment);

        if (payment.getPaymentType() == PaymentType.DEPOSIT) {
            booking.setDepositPaid(
                    booking.getDepositPaid()
                            .add(payment.getAmount())
            );

            booking.setStatus(
                    BookingStatus.CONFIRMED
            );
        }

        bookingRepository.save(booking);

        /*
         * Không chuyển unit sang OCCUPIED tại đây.
         * Unit chỉ chuyển sang OCCUPIED khi staff thực hiện check-in.
         */

        return PaymentResponse.builder()
                .id(payment.getId())
                .transactionId(payment.getTransactionId())
                .bookingId(booking.getId())
                .amount(payment.getAmount())
                .paymentType(payment.getPaymentType())
                .status(payment.getStatus())
                .paymentMethod(payment.getPaymentMethod())
                .paymentTime(payment.getPaymentTime())
                .build();
    }
}