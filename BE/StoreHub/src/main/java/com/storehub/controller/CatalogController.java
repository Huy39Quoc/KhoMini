package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.dto.response.CatalogOverviewResponse;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.dto.response.UnitTypeCatalogResponse;
import com.storehub.service.CatalogService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/catalog")
@RequiredArgsConstructor
@Tag(name = "Catalog", description = "APIs tra cứu danh mục cơ sở, kích thước và giá thuê kho")
public class CatalogController {

    private final CatalogService catalogService;

    @GetMapping("/overview")
    @Operation(summary = "Lấy tổng quan danh mục bao gồm danh sách cơ sở và kích thước kho")
    public ResponseEntity<ApiResponse<CatalogOverviewResponse>> getOverview(
            @RequestParam(required = false) UUID facilityId
    ) {
        CatalogOverviewResponse data = catalogService.getCatalogOverview(facilityId);
        return ResponseEntity.ok(ApiResponse.success("Catalog overview retrieved successfully", data));
    }

    @GetMapping("/facilities")
    @Operation(summary = "Lấy danh sách các cơ sở kho (Facilities)")
    public ResponseEntity<ApiResponse<List<FacilityResponse>>> getFacilities() {
        List<FacilityResponse> facilities = catalogService.getAllFacilities();
        return ResponseEntity.ok(ApiResponse.success("Facilities retrieved successfully", facilities));
    }

    @GetMapping("/unit-types")
    @Operation(summary = "Lấy danh sách các loại kích thước kho, giá thuê tháng và số lượng kho trống")
    public ResponseEntity<ApiResponse<List<UnitTypeCatalogResponse>>> getUnitTypes(
            @RequestParam(required = false) UUID facilityId
    ) {
        List<UnitTypeCatalogResponse> unitTypes = catalogService.getUnitTypes(facilityId);
        return ResponseEntity.ok(ApiResponse.success("Unit types retrieved successfully", unitTypes));
    }
}