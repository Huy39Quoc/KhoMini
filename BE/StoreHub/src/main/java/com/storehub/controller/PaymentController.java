package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.dto.request.PaymentConfirmationRequest;
import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.service.PaymentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
@Tag(name = "Payment", description = "APIs quản lý giao dịch thanh toán cọc và phí kho")
public class PaymentController {

    private final PaymentService paymentService;

    @PostMapping("/initiate")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Khởi tạo giao dịch thanh toán cọc/phí kho – trả về QR Code VietQR")
    public ResponseEntity<ApiResponse<PaymentResponse>> initiatePayment(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody PaymentInitiationRequest request
    ) {
        PaymentResponse response = paymentService.initiatePayment(userDetails.getUsername(), request);
        return ResponseEntity.ok(ApiResponse.success("Payment transaction initiated successfully", response));
    }

    @PostMapping("/confirm")
    @Operation(summary = "Xác nhận thanh toán thành công (Webhook hoặc mô phỏng hoàn tất)")
    public ResponseEntity<ApiResponse<PaymentResponse>> confirmPayment(
            @Valid @RequestBody PaymentConfirmationRequest request
    ) {
        PaymentResponse response = paymentService.confirmPayment(request);
        return ResponseEntity.ok(ApiResponse.success("Payment confirmed successfully", response));
    }
}
