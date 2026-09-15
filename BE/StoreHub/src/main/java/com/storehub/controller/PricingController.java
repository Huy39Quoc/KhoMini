package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.service.PricingService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/pricing")
@RequiredArgsConstructor
@Tag(name = "Pricing", description = "APIs tính toán chi phí thuê kho")
public class PricingController {

    private final PricingService pricingService;

    @PostMapping("/quote")
    @Operation(summary = "Lấy báo giá chi tiết gồm tiền thuê, tiền cọc và phụ phí")
    public ResponseEntity<ApiResponse<RentalQuoteResponse>> getRentalQuote(
            @Valid @RequestBody RentalQuoteRequest request
    ) {
        RentalQuoteResponse response = pricingService.calculateRentalQuote(request);
        return ResponseEntity.ok(ApiResponse.success("Rental quote calculated successfully", response));
    }
}