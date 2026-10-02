package com.storehub.controller;

import com.storehub.common.ApiResponse;
import com.storehub.dto.request.UpdateUnitTypePriceRequest;
import com.storehub.dto.response.UnitTypeCatalogResponse;
import com.storehub.service.UnitTypeManagementService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/unit-types")
@RequiredArgsConstructor
@Tag(name = "Unit Types", description = "Quản lý giá thuê và tiền cọc theo loại kho")
@SecurityRequirement(name = "Bearer Authentication")
public class UnitTypeController {

    private final UnitTypeManagementService unitTypeManagementService;

    @PutMapping("/{unitTypeId}/price")
    @PreAuthorize("hasAnyRole('ADMIN', 'BUSINESS_MANAGER')")
    @Operation(summary = "Cập nhật giá thuê tháng và tiền cọc của loại kho")
    public ApiResponse<UnitTypeCatalogResponse> updatePrice(
            @PathVariable UUID unitTypeId,
            @Valid @RequestBody UpdateUnitTypePriceRequest request
    ) {
        return ApiResponse.success(
                "Unit type price updated successfully",
                unitTypeManagementService.updatePrice(unitTypeId, request)
        );
    }
}
