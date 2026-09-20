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
import com.storehub.repository.StorageUnitRepository;
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
public class PaymentServiceImpl implements PaymentService {

    private final PaymentRepository paymentRepository;
    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final StorageUnitRepository storageUnitRepository;

    @Override
    @Transactional
    public PaymentResponse initiatePayment(String customerEmail, PaymentInitiationRequest request) {
        // 1. Xác định khách hàng
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        // 2. Tìm booking của khách
        Booking booking = bookingRepository.findByIdAndCustomerId(request.getBookingId(), customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        // 3. Xác định số tiền cần thanh toán (Enum == so sánh type-safe)
        BigDecimal payableAmount = (request.getPaymentType() == PaymentType.DEPOSIT)
                ? (booking.getStorageUnit().getUnitType() != null
                    ? booking.getStorageUnit().getUnitType().getDepositAmount()
                    : BigDecimal.ZERO)
                : booking.getTotalRentalFee();

        // 4. Tạo transaction ID và payment
        String transactionId = "TXN-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();

        Payment payment = Payment.builder()
                .transactionId(transactionId)
                .booking(booking)
                .amount(payableAmount)
                .paymentType(request.getPaymentType())
                .status(PaymentStatus.PENDING)
                .paymentMethod(request.getPaymentMethod())
                .paymentTime(LocalDateTime.now())
                .build();

        Payment savedPayment = paymentRepository.save(payment);

        // 5. Sinh QR Code VietQR
        String qrCodeUrl = String.format(
                "https://img.vietqr.io/image/970422-STOREHUB-%s.png?amount=%s&addInfo=%s",
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
    public PaymentResponse confirmPayment(PaymentConfirmationRequest request) {
        // 1. Tìm giao dịch
        Payment payment = paymentRepository.findByTransactionId(request.getTransactionId())
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));

        // 2. Kiểm tra đã xử lý chưa (so sánh Enum == type-safe)
        if (payment.getStatus() == PaymentStatus.PAID) {
            throw new AppException(ErrorCode.PAYMENT_ALREADY_PROCESSED);
        }

        // 3. Cập nhật trạng thái payment
        payment.setStatus(PaymentStatus.PAID);
        payment.setPaymentTime(LocalDateTime.now());
        paymentRepository.save(payment);

        // 4. Cập nhật booking
        Booking booking = payment.getBooking();
        if (payment.getPaymentType() == PaymentType.DEPOSIT) {
            booking.setDepositPaid(booking.getDepositPaid().add(payment.getAmount()));
        }
        booking.setStatus(BookingStatus.CONFIRMED);
        bookingRepository.save(booking);

        // 5. Cập nhật trạng thái kho → OCCUPIED
        if (booking.getStorageUnit() != null) {
            booking.getStorageUnit().setStatus(UnitStatus.OCCUPIED);
            storageUnitRepository.save(booking.getStorageUnit());
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
                .build();
    }
}
