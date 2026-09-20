package com.storehub.service;

import com.storehub.dto.request.PaymentConfirmationRequest;
import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;

public interface PaymentService {

    /**
     * Khởi tạo giao dịch thanh toán (tiền cọc hoặc phí thuê).
     * Trả về thông tin giao dịch kèm QR Code VietQR để khách thanh toán.
     *
     * @param customerEmail email khách hàng (từ JWT)
     * @param request       thông tin thanh toán
     * @return chi tiết giao dịch + QR URL
     */
    PaymentResponse initiatePayment(String customerEmail, PaymentInitiationRequest request);

    /**
     * Xác nhận giao dịch đã thanh toán thành công.
     * Cập nhật trạng thái booking → CONFIRMED, unit → OCCUPIED.
     * Endpoint này dành cho Webhook hoặc mô phỏng hoàn tất thanh toán.
     *
     * @param request chứa transactionId cần xác nhận
     * @return chi tiết giao dịch đã xác nhận
     */
    PaymentResponse confirmPayment(PaymentConfirmationRequest request);
}
