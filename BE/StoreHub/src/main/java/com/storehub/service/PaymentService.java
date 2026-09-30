package com.storehub.service;

import com.storehub.dto.request.PaymentConfirmationRequest;
import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.entity.Booking;

import java.math.BigDecimal;
import java.util.UUID;

public interface PaymentService {

    PaymentResponse initiatePayment(
            String customerEmail,
            PaymentInitiationRequest request
    );

    PaymentResponse confirmPayment(
            String customerEmail,
            PaymentConfirmationRequest request
    );

    PaymentResponse getPendingExtensionPayment(
            String customerEmail,
            UUID bookingId
    );

    PaymentResponse getPendingOverduePayment(
            String customerEmail,
            UUID bookingId
    );

    // Hoàn (một phần hoặc toàn bộ) tiền cọc của booking. Trả về số tiền thực tế đã hoàn.
    // Payment cọc gốc -> REFUNDED (hoàn hết) hoặc giảm còn phần giữ lại + 1 Payment REFUNDED cho phần hoàn.
    BigDecimal refundDeposit(Booking booking, BigDecimal refundAmount);

    // Dùng khi nhân viên nghiệm thu trả kho: chặn nếu còn phí trễ hạn chưa thanh toán,
    // huỷ yêu cầu gia hạn đang treo, rồi hoàn toàn bộ tiền cọc. Trả về số tiền đã hoàn.
    BigDecimal refundDepositOnReturn(Booking booking);
}
