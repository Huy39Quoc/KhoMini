package com.storehub.controller;

import com.storehub.common.ApiResponse;
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
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

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
    @SecurityRequirement(name = "bearerAuth")
    @Operation(
            summary = "Khởi tạo giao dịch thanh toán cọc/phí kho – trả về QR Code VietQR"
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
    @Operation(summary = "Xác nhận thanh toán thành công")
    public ResponseEntity<ApiResponse<PaymentResponse>> confirmPayment(
            @Valid @RequestBody PaymentConfirmationRequest request
    ) {
        PaymentResponse response = paymentService.confirmPayment(request);

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
    @Operation(summary = "Lấy phí quá hạn đang chờ thanh toán và QR VietQR")
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
}