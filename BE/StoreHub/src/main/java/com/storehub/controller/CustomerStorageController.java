package com.storehub.controller;

import com.storehub.common.ApiResponse;
import com.storehub.dto.request.CheckoutRequest;
import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.dto.request.ResetPinRequest;
import com.storehub.dto.request.SetupPinRequest;
import com.storehub.dto.request.UnlockRequest;
import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.ContractOperationResponse;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.dto.response.SmartAccessResponse;
import com.storehub.dto.response.GatePassResponse;
import com.storehub.service.CustomerStorageService;
import com.storehub.service.GatePassService;
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
import java.util.List;

@RestController
@RequestMapping("/api/v1/customer/storage")
@RequiredArgsConstructor
@Tag(name = "Customer Storage", description = "APIs quản lý kho đang thuê dành cho khách hàng")
@SecurityRequirement(name = "Bearer Authentication")
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerStorageController {

    private final CustomerStorageService customerStorageService;
    private final GatePassService gatePassService;

    @PostMapping("/{bookingId}/gate-pass")
    @Operation(summary = "Cấp QR ra cổng có hạn dùng cho kho ACTIVE của khách")
    public ResponseEntity<ApiResponse<GatePassResponse>> issueGatePass(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        return ResponseEntity.ok()
                .header("Cache-Control", "no-store")
                .body(ApiResponse.success("Gate pass issued",
                        gatePassService.issue(bookingId, userDetails.getUsername())));
    }

    @GetMapping("/my-units")
    @Operation(summary = "Chỉ lấy ngăn kho đã bàn giao và đang thuê (ACTIVE)")
    public ResponseEntity<ApiResponse<List<MyUnitResponse>>> getMyRentedUnits(
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        List<MyUnitResponse> result = customerStorageService.getMyRentedUnits(userDetails.getUsername());

        return ResponseEntity.ok(ApiResponse.<List<MyUnitResponse>>builder()
                .success(true)
                .message("Rented units retrieved successfully")
                .data(result)
                .build());
    }

    @GetMapping("/awaiting-handover")
    @Operation(summary = "Lấy booking đã đặt cọc, đang chờ nhận kho (CONFIRMED)")
    public ResponseEntity<ApiResponse<List<MyUnitResponse>>> getAwaitingHandover(
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        return ResponseEntity.ok(ApiResponse.success("Bookings awaiting handover retrieved",
                customerStorageService.getAwaitingHandover(userDetails.getUsername())));
    }

    @GetMapping("/{bookingId}/access")
    @Operation(summary = "Xem trạng thái khóa thông minh (đã có PIN chưa, đang khóa/mở). Không trả PIN đã lưu")
    public ResponseEntity<ApiResponse<SmartAccessResponse>> getSmartAccess(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        SmartAccessResponse response = customerStorageService.getSmartAccessInfo(bookingId, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.<SmartAccessResponse>builder()
                .success(true)
                .message("Smart access information retrieved successfully")
                .data(response)
                .build());
    }

    @PostMapping("/{bookingId}/access/pin/setup")
    @Operation(summary = "Tạo PIN lần đầu: để trống newPin = hệ thống cấp (trả về 1 lần), có newPin = khách tự đặt")
    public ResponseEntity<ApiResponse<SmartAccessResponse>> setupAccessPin(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @Valid SetupPinRequest request
    ) {
        SmartAccessResponse response = customerStorageService.setupPin(bookingId, userDetails.getUsername(), request);
        return ResponseEntity.ok(ApiResponse.<SmartAccessResponse>builder()
                .success(true)
                .message("PIN created successfully")
                .data(response)
                .build());
    }

    @PostMapping("/{bookingId}/access/pin/reset")
    @Operation(summary = "Quên PIN: nhập mật khẩu tài khoản để đặt lại PIN (tự đặt hoặc hệ thống cấp)")
    public ResponseEntity<ApiResponse<SmartAccessResponse>> resetAccessPin(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @Valid ResetPinRequest request
    ) {
        SmartAccessResponse response = customerStorageService.resetPin(bookingId, userDetails.getUsername(), request);
        return ResponseEntity.ok(ApiResponse.<SmartAccessResponse>builder()
                .success(true)
                .message("PIN reset successfully")
                .data(response)
                .build());
    }

    @PutMapping("/{bookingId}/access/pin")
    @Operation(summary = "Đổi mã PIN (6 số) - phải nhập đúng PIN hiện tại")
    public ResponseEntity<ApiResponse<SmartAccessResponse>> updateAccessPin(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @Valid UpdatePinRequest request
    ) {
        SmartAccessResponse response = customerStorageService.updateAccessPin(bookingId, userDetails.getUsername(), request);
        return ResponseEntity.ok(ApiResponse.<SmartAccessResponse>builder()
                .success(true)
                .message("PIN updated successfully")
                .data(response)
                .build());
    }

    @PostMapping("/{bookingId}/access/unlock")
    @Operation(summary = "Mở khóa ngăn kho bằng PIN (mô phỏng - không có phần cứng khóa thật đứng sau)")
    public ResponseEntity<ApiResponse<SmartAccessResponse>> unlockUnit(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @Valid UnlockRequest request
    ) {
        SmartAccessResponse response = customerStorageService.unlockWithPin(bookingId, userDetails.getUsername(), request);
        return ResponseEntity.ok(ApiResponse.<SmartAccessResponse>builder()
                .success(true)
                .message("Unit unlocked successfully")
                .data(response)
                .build());
    }

    @PostMapping("/{bookingId}/access/lock")
    @Operation(summary = "Đóng khóa ngăn kho (không cần PIN)")
    public ResponseEntity<ApiResponse<SmartAccessResponse>> lockUnit(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        SmartAccessResponse response = customerStorageService.setLockState(bookingId, userDetails.getUsername(), true);
        return ResponseEntity.ok(ApiResponse.<SmartAccessResponse>builder()
                .success(true)
                .message("Unit locked successfully")
                .data(response)
                .build());
    }

    @PostMapping("/{bookingId}/extend")
    @Operation(summary = "Yêu cầu gia hạn hợp đồng thuê kho")
    public ResponseEntity<ApiResponse<ContractOperationResponse>> extendRental(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @Valid ExtendRentalRequest request
    ) {
        ContractOperationResponse response = customerStorageService.extendRental(bookingId, userDetails.getUsername(), request);
        return ResponseEntity.ok(ApiResponse.<ContractOperationResponse>builder()
                .success(true)
                .message("Rental extended successfully")
                .data(response)
                .build());
    }

    @DeleteMapping("/{bookingId}/extend")
    @Operation(summary = "Hủy yêu cầu gia hạn đang chờ thanh toán")
    public ResponseEntity<ApiResponse<ContractOperationResponse>> cancelPendingExtension(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        ContractOperationResponse response = customerStorageService.cancelPendingExtension(bookingId, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.<ContractOperationResponse>builder()
                .success(true)
                .message("Pending extension cancelled successfully")
                .data(response)
                .build());
    }

    @PostMapping("/{bookingId}/checkout")
    @Operation(summary = "Gửi yêu cầu và đặt lịch hẹn trả kho")
    public ResponseEntity<ApiResponse<ContractOperationResponse>> requestCheckout(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody @Valid CheckoutRequest request
    ) {
        ContractOperationResponse response = customerStorageService.requestCheckout(bookingId, userDetails.getUsername(), request);
        return ResponseEntity.ok(ApiResponse.<ContractOperationResponse>builder()
                .success(true)
                .message("Checkout scheduled successfully")
                .data(response)
                .build());
    }
    @GetMapping("/{bookingId}/extend/pending-payment")
    @Operation(summary = "Lấy lại giao dịch thanh toán gia hạn đang chờ (nếu có), để tiếp tục thanh toán")
    public ResponseEntity<ApiResponse<PaymentResponse>> getPendingExtensionPayment(
            @PathVariable UUID bookingId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        PaymentResponse response = customerStorageService.getPendingExtensionPayment(bookingId, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.<PaymentResponse>builder()
                .success(true)
                .message("Pending extension payment retrieved successfully")
                .data(response)
                .build());
    }
}
