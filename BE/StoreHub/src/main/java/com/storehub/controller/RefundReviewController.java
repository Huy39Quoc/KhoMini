package com.storehub.controller;

import com.storehub.common.ApiResponse;
import com.storehub.dto.request.RefundGatewayMetadataRequest;
import com.storehub.dto.response.RefundRequestResponse;
import com.storehub.service.impl.RefundReviewService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/facility/{facilityId}/refunds")
@RequiredArgsConstructor
@PreAuthorize("hasRole('FACILITY_MANAGER')")
public class RefundReviewController {
    private final RefundReviewService service;

    @GetMapping
    public ApiResponse<List<RefundRequestResponse>> list(@PathVariable UUID facilityId,
                                                         @AuthenticationPrincipal UserDetails principal) {
        return ApiResponse.success("Refund requests", service.list(facilityId, principal.getUsername()));
    }

    @PutMapping("/{refundId}/gateway-details")
    public ApiResponse<RefundRequestResponse> provideMetadata(@PathVariable UUID facilityId,
            @PathVariable UUID refundId, @AuthenticationPrincipal UserDetails principal,
            @RequestBody @Valid RefundGatewayMetadataRequest request) {
        return ApiResponse.success("Original payment details recorded",
                service.provideMetadata(facilityId, refundId, principal.getUsername(), request));
    }

    @PostMapping("/{refundId}/retry")
    public ApiResponse<RefundRequestResponse> retry(@PathVariable UUID facilityId,
            @PathVariable UUID refundId, @AuthenticationPrincipal UserDetails principal) {
        return ApiResponse.success("Rejected refund queued again",
                service.retryRejected(facilityId, refundId, principal.getUsername()));
    }

    @PostMapping("/{refundId}/reconcile")
    public ApiResponse<Void> reconcile(@PathVariable UUID facilityId,
            @PathVariable UUID refundId, @AuthenticationPrincipal UserDetails principal) {
        service.reconcile(facilityId, refundId, principal.getUsername());
        return ApiResponse.success("VNPay reconciliation checked", null);
    }
}
