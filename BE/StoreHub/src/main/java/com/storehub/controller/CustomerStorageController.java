package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.dto.request.CheckoutRequest;
import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.ContractOperationResponse;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.SmartAccessResponse;
import com.storehub.entity.User;
import com.storehub.service.CustomerStorageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/customer/my-units")
@RequiredArgsConstructor
@Tag(name = "Customer Storage", description = "APIs quản lý kho đang thuê dành cho khách hàng")
@SecurityRequirement(name = "Bearer Authentication")
public class CustomerStorageController {

    private final CustomerStorageService customerStorageService;

    @GetMapping
    @Operation(summary = "Lấy danh sách các ngăn kho đang thuê của khách hàng hiện tại")
    public ResponseEntity<ApiResponse<List<MyUnitResponse>>> getMyRentedUnits(
            @AuthenticationPrincipal User currentUser
    ) {
        List<MyUnitResponse> result = customerStorageService.getMyRentedUnits(currentUser.getId());

        return ResponseEntity.ok(ApiResponse.<List<MyUnitResponse>>builder()
                .success(true)
                .message("Rented units retrieved successfully")
                .data(result)
                .build());
    }

    @GetMapping("/{bookingId}/access")
    @Operation(summary = "Lấy mã PIN và QR Code mở khóa cho đơn thuê đang hoạt động")
    public ResponseEntity<ApiResponse<SmartAccessResponse>> getSmartAccess(
            @PathVariable Long bookingId,
            @AuthenticationPrincipal User currentUser
    ) {
        SmartAccessResponse response = customerStorageService.getSmartAccessInfo(bookingId, currentUser.getId());
        return ResponseEntity.ok(ApiResponse.<SmartAccessResponse>builder()
                .success(true)
                .message("Smart access information retrieved successfully")
                .data(response)
                .build());
    }

    @PutMapping("/{bookingId}/access/pin")
    @Operation(summary = "Đổi mã PIN mở khóa cửa kho (6 số)")
    public ResponseEntity<ApiResponse<SmartAccessResponse>> updateAccessPin(
            @PathVariable Long bookingId,
            @AuthenticationPrincipal User currentUser,
            @RequestBody @Valid UpdatePinRequest request
    ) {
        SmartAccessResponse response = customerStorageService.updateAccessPin(bookingId, currentUser.getId(), request);
        return ResponseEntity.ok(ApiResponse.<SmartAccessResponse>builder()
                .success(true)
                .message("PIN updated successfully")
                .data(response)
                .build());
    }

    @PostMapping("/{bookingId}/extend")
    @Operation(summary = "Yêu cầu gia hạn hợp đồng thuê kho")
    public ResponseEntity<ApiResponse<ContractOperationResponse>> extendRental(
            @PathVariable Long bookingId,
            @AuthenticationPrincipal User currentUser,
            @RequestBody @Valid ExtendRentalRequest request
    ) {
        ContractOperationResponse response = customerStorageService.extendRental(bookingId, currentUser.getId(), request);
        return ResponseEntity.ok(ApiResponse.<ContractOperationResponse>builder()
                .success(true)
                .message("Rental extended successfully")
                .data(response)
                .build());
    }

    @PostMapping("/{bookingId}/checkout")
    @Operation(summary = "Gửi yêu cầu và đặt lịch hẹn trả kho")
    public ResponseEntity<ApiResponse<ContractOperationResponse>> requestCheckout(
            @PathVariable Long bookingId,
            @AuthenticationPrincipal User currentUser,
            @RequestBody @Valid CheckoutRequest request
    ) {
        ContractOperationResponse response = customerStorageService.requestCheckout(bookingId, currentUser.getId(), request);
        return ResponseEntity.ok(ApiResponse.<ContractOperationResponse>builder()
                .success(true)
                .message("Checkout scheduled successfully")
                .data(response)
                .build());
    }
}