package com.storehub.controller;

import com.storehub.common.ApiResponse;
import com.storehub.common.PageResponse;
import com.storehub.dto.request.RefundGatewayMetadataRequest;
import com.storehub.dto.response.RefundRequestResponse;
import com.storehub.service.impl.RefundReviewService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/facility/{facilityId}/refunds")
@RequiredArgsConstructor
public class RefundReviewController {
    private final RefundReviewService service;

    @GetMapping
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('REFUND_VIEW')")
    public ApiResponse<PageResponse<RefundRequestResponse>> list(@PathVariable UUID facilityId,
            @AuthenticationPrincipal UserDetails principal,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success("Refund requests",
                service.list(facilityId, principal.getUsername(), page, size));
    }

    @PutMapping("/{refundId}/gateway-details")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('REFUND_APPROVE')")
    public ApiResponse<RefundRequestResponse> provideMetadata(@PathVariable UUID facilityId,
            @PathVariable UUID refundId, @AuthenticationPrincipal UserDetails principal,
            @RequestBody @Valid RefundGatewayMetadataRequest request) {
        return ApiResponse.success("Original payment details recorded",
                service.provideMetadata(facilityId, refundId, principal.getUsername(), request));
    }

    @PostMapping("/{refundId}/retry")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('REFUND_APPROVE')")
    public ApiResponse<RefundRequestResponse> retry(@PathVariable UUID facilityId,
            @PathVariable UUID refundId, @AuthenticationPrincipal UserDetails principal) {
        return ApiResponse.success("Rejected refund queued again",
                service.retryRejected(facilityId, refundId, principal.getUsername()));
    }

    @PostMapping("/{refundId}/reconcile")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('REFUND_VIEW')")
    public ApiResponse<Void> reconcile(@PathVariable UUID facilityId,
            @PathVariable UUID refundId, @AuthenticationPrincipal UserDetails principal) {
        service.reconcile(facilityId, refundId, principal.getUsername());
        return ApiResponse.success("VNPay reconciliation checked", null);
    }

    @PostMapping("/{refundId}/confirm-bank-transfer")
    @PreAuthorize("hasRole('FACILITY_MANAGER') and hasAuthority('REFUND_APPROVE')")
    public ApiResponse<RefundRequestResponse> confirmBankTransfer(@PathVariable UUID facilityId,
            @PathVariable UUID refundId, @AuthenticationPrincipal UserDetails principal,
            @RequestBody @Valid com.storehub.dto.request.ConfirmBankTransferRequest request) {
        return ApiResponse.success("Bank transfer confirmed successfully",
                service.confirmBankTransfer(facilityId, refundId, principal.getUsername(), request));
    }
}
