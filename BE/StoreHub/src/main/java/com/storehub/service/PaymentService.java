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

    BigDecimal refundDepositOnReturn(Booking booking, BigDecimal damageFee, String damageReason);

    com.storehub.common.PageResponse<PaymentResponse> getMyPaymentHistory(
            String customerEmail, org.springframework.data.domain.Pageable pageable);

    com.storehub.common.PageResponse<PaymentResponse> getFacilityPaymentHistory(
            String userEmail, UUID facilityId, org.springframework.data.domain.Pageable pageable);

    com.storehub.common.PageResponse<PaymentResponse> getAllPaymentHistory(
            org.springframework.data.domain.Pageable pageable);

    PaymentResponse getPaymentDetail(UUID paymentId, String userEmail);
}
