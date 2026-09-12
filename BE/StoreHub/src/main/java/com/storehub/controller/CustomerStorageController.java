package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.entity.User;
import com.storehub.service.CustomerStorageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
                .message("Lấy danh sách kho thành công")
                .data(result)
                .build());
    }
}