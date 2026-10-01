package com.storehub.controller;

import com.storehub.common.ApiResponse;
import com.storehub.dto.request.PaymentConfirmationRequest;
import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.enums.PaymentStatus;
import com.storehub.service.PaymentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
@Tag(
        name = "Payment",
        description = "APIs quản lý giao dịch thanh toán cọc và phí kho"
)
public class PaymentController {

    private final PaymentService paymentService;

    @PostMapping("/initiate")
    @PreAuthorize("hasRole('CUSTOMER')")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(
            summary = "Khởi tạo giao dịch thanh toán cọc/phí kho – trả về VNPay Sandbox Payment URL"
    )
    public ResponseEntity<ApiResponse<PaymentResponse>> initiatePayment(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody PaymentInitiationRequest request
    ) {
        PaymentResponse response = paymentService.initiatePayment(
                userDetails.getUsername(),
                request
        );

        return ResponseEntity.ok(
                ApiResponse.success(
                        "Payment transaction initiated successfully",
                        response
                )
        );
    }

    @PostMapping("/confirm")
    @PreAuthorize("hasRole('CUSTOMER')")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Xác nhận thanh toán thành công")
    public ResponseEntity<ApiResponse<PaymentResponse>> confirmPayment(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody PaymentConfirmationRequest request
    ) {
        PaymentResponse response = paymentService.confirmPayment(
                userDetails.getUsername(),
                request
        );

        return ResponseEntity.ok(
                ApiResponse.success(
                        "Payment confirmed successfully",
                        response
                )
        );
    }

    @GetMapping("/bookings/{bookingId}/overdue")
    @PreAuthorize("hasRole('CUSTOMER')")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Lấy phí quá hạn đang chờ thanh toán và VNPay Payment URL")
    public ResponseEntity<ApiResponse<PaymentResponse>>
    getPendingOverduePayment(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        PaymentResponse response = paymentService.getPendingOverduePayment(
                userDetails.getUsername(),
                bookingId
        );

        return ResponseEntity.ok(
                ApiResponse.success(
                        "Pending overdue payment retrieved successfully",
                        response
                )
        );
    }

    @GetMapping("/vnpay-return")
    @Operation(summary = "VNPay callback URL nhận kết quả thanh toán từ VNPay")
    public ResponseEntity<String> vnpayReturn(@RequestParam Map<String, String> queryParams) {
        try {
            PaymentResponse response = paymentService.processVnpayCallback(queryParams);
            boolean isPaid = response.getStatus() == PaymentStatus.PAID;
            String html = """
                <!DOCTYPE html>
                <html lang="vi">
                <head>
                    <meta charset="UTF-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <title>Kết quả thanh toán VNPay - StoreHub</title>
                    <style>
                        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f4f6f9; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
                        .card { background: white; padding: 40px; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.1); text-align: center; max-width: 420px; width: 90%%; }
                        .icon { width: 80px; height: 80px; background: #4caf50; color: white; border-radius: 50%%; display: flex; align-items: center; justify-content: center; font-size: 40px; margin: 0 auto 20px; }
                        .icon.error { background: #f44336; }
                        h2 { margin: 0 0 10px; color: #1e3c72; }
                        p { color: #666; font-size: 14px; margin: 5px 0; }
                        .txn { font-weight: bold; color: #333; font-size: 16px; margin-top: 15px; }
                        .badge { display: inline-block; padding: 6px 16px; background: #e8f5e9; color: #2e7d32; border-radius: 20px; font-weight: bold; margin-top: 15px; }
                        .btn { display: inline-block; margin-top: 25px; padding: 12px 24px; background: #1e3c72; color: white; border-radius: 8px; text-decoration: none; font-weight: bold; }
                    </style>
                </head>
                <body>
                    <div class="card">
                        <div class="icon %s">%s</div>
                        <h2>%s</h2>
                        <p>%s</p>
                        <p class="txn">Mã giao dịch: %s</p>
                        <div class="badge">Trạng thái: %s</div>
                        <br>
                        <a href="storehub://payment-result" class="btn">Quay lại ứng dụng StoreHub</a>
                        <p style="margin-top: 15px; font-size: 13px; color: #777;">(Nếu không tự chuyển, bạn vuốt màn hình quay lại app StoreHub)</p>
                    </div>
                </body>
                </html>
                """.formatted(
                    isPaid ? "" : "error",
                    isPaid ? "✓" : "✕",
                    isPaid ? "Thanh Toán Thành Công!" : "Thanh Toán Thất Bại",
                    isPaid ? "Giao dịch qua VNPAY đã hoàn tất thành công." : "Giao dịch không thành công hoặc đã bị hủy.",
                    response.getTransactionId() != null ? response.getTransactionId() : "—",
                    response.getStatus() != null ? response.getStatus().name() : "FAILED"
            );
            return ResponseEntity.ok().contentType(org.springframework.http.MediaType.TEXT_HTML).body(html);
        } catch (Exception e) {
            String errorHtml = """
                <!DOCTYPE html>
                <html lang="vi">
                <head><meta charset="UTF-8"><title>Lỗi Thanh Toán</title></head>
                <body style="font-family: sans-serif; text-align: center; padding: 50px;">
                    <h2 style="color: red;">Lỗi Xử Lý Giao Dịch</h2>
                    <p>%s</p>
                </body>
                </html>
                """.formatted(e.getMessage());
            return ResponseEntity.badRequest().contentType(org.springframework.http.MediaType.TEXT_HTML).body(errorHtml);
        }
    }

    @GetMapping("/vnpay-ipn")
    @Operation(summary = "VNPay IPN URL (Server-to-Server callback)")
    public ResponseEntity<Map<String, String>> vnpayIpn(@RequestParam Map<String, String> queryParams) {
        Map<String, String> result = new java.util.HashMap<>();
        try {
            paymentService.processVnpayCallback(queryParams);
            result.put("RspCode", "00");
            result.put("Message", "Confirm Success");
            return ResponseEntity.ok(result);
        } catch (com.storehub.exception.AppException e) {
            result.put("RspCode", "01");
            result.put("Message", e.getMessage());
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            result.put("RspCode", "99");
            result.put("Message", "Unknown Error");
            return ResponseEntity.ok(result);
        }
    }
}
