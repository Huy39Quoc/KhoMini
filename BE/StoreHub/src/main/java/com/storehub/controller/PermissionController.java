package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.PermissionCreateRequest;
import com.storehub.dto.request.PermissionUpdateRequest;
import com.storehub.dto.response.PermissionResponse;
import com.storehub.service.PermissionService;
import io.swagger.v3.oas.annotations.Operation;
import jakarta.validation.Valid;
import lombok.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
@RestController
@RequestMapping("api/v1/permissions")
@Tag(
        name = "Permission",
        description = "API quản lý các quyền trong hệ thống"
)
@RequiredArgsConstructor
@Slf4j
public class PermissionController {

    private final PermissionService permissionService;

    @GetMapping("{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'FACILITY_MANAGER', 'BUSINESS_MANAGER')")
    @Operation(summary = "Lấy quyền theo ID")
    public ResponseEntity<ApiResponse<PermissionResponse>> getById(@PathVariable UUID id) {
        PermissionResponse response = permissionService.getById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Create a new permission")
    public ResponseEntity<ApiResponse<PermissionResponse>> create(
            @Valid @RequestBody PermissionCreateRequest request) {

        PermissionResponse response = permissionService.create(request);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success("Created permission successfully", response));
    }

    @PutMapping("{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Update an existing permission")
    public ResponseEntity<ApiResponse<PermissionResponse>> update(
            @PathVariable UUID id,
            @Valid @RequestBody PermissionUpdateRequest request) {

        PermissionResponse response = permissionService.update(id, request);

        return ResponseEntity.ok(
                ApiResponse.success("Updated permission successfully.", response));
    }

    @DeleteMapping("{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Delete a permission")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {
        permissionService.delete(id);

        return ResponseEntity.ok(
                ApiResponse.success("Deleted permission successfully.", null));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'FACILITY_MANAGER', 'BUSINESS_MANAGER')")
    @Operation(summary = "Get all permissions with filtering and pagination")
    public ResponseEntity<ApiResponse<PageResponse<PermissionResponse>>> getAll(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Boolean isActive,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir
    ) {
        PageResponse<PermissionResponse> response =
                permissionService.getAll(search, isActive, page, size, sortBy, sortDir);

        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
