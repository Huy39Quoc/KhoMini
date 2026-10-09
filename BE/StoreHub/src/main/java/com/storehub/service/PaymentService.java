package com.storehub.service;

import com.storehub.dto.request.PaymentConfirmationRequest;
import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.entity.Booking;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

public interface PaymentService {

    PaymentResponse initiatePayment(
            String customerEmail,
            PaymentInitiationRequest request
    );

    // Khách chỉ được HỎI trạng thái giao dịch. Việc đánh dấu PAID chỉ xảy ra khi
    // VNPay gọi về (vnpay-return / vnpay-ipn) với chữ ký hợp lệ.
    PaymentResponse getPaymentStatus(String customerEmail, String transactionId);

    PaymentResponse confirmPayment(
            String customerEmail,
            PaymentConfirmationRequest request
    );

    PaymentResponse confirmPayment(
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

    PaymentResponse processVnpayCallback(Map<String, String> queryParams);

    // Tạo yêu cầu hoàn cọc bền vững; trả về số tiền được yêu cầu, chưa phải tiền đã về tài khoản.
    BigDecimal refundDeposit(Booking booking, BigDecimal refundAmount);

    // Khách huỷ đơn đã CONFIRMED: hoàn tiền (cọc + tiền thuê đã trả) theo bậc chính sách huỷ của cơ sở.
    // Ưu tiên hoàn vào khoản cọc trước, phần còn lại vào tiền thuê. Trả về tổng số tiền yêu cầu hoàn.
    BigDecimal refundOnCancellation(Booking booking);

    // Dùng khi nhân viên nghiệm thu trả kho: chặn nếu còn phí trễ hạn chưa thanh toán,
    // huỷ yêu cầu gia hạn đang treo, rồi yêu cầu hoàn cọc. Trả về số tiền yêu cầu hoàn.
    BigDecimal refundDepositOnReturn(Booking booking);

    java.util.List<PaymentResponse> getMyPaymentHistory(String customerEmail);

    java.util.List<PaymentResponse> getFacilityPaymentHistory(String userEmail, UUID facilityId);

    java.util.List<PaymentResponse> getAllPaymentHistory();

    PaymentResponse getPaymentDetail(UUID paymentId, String userEmail);
}
