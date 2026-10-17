package com.storehub.controller;

import com.storehub.common.ApiResponse;
import com.storehub.common.PageResponse;
import com.storehub.dto.request.RolePermissionBulkAssignRequest;
import com.storehub.dto.request.RolePermissionCreateRequest;
import com.storehub.dto.request.RolePermissionUpdateRequest;
import com.storehub.dto.response.RolePermissionResponse;
import com.storehub.service.RolePermissionService;
import io.swagger.v3.oas.annotations.Operation;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/role-permissions")
@Tag(
        name = "Role Permission",
        description = "API quản lý việc gán và thu hồi quyền cho các vai trò"
)
@RequiredArgsConstructor
@Slf4j
public class RolePermissionController {

    private final RolePermissionService rolePermissionService;

    @PostMapping("/bulk-assign")
    @PreAuthorize("hasRole('ADMIN') and hasAuthority('ROLE_PERMISSION_ASSIGN')")
    @Operation(summary = "Gán nhiều quyền cho vai trò")
    public ResponseEntity<ApiResponse<List<RolePermissionResponse>>> bulkAssign(
            @Valid @RequestBody RolePermissionBulkAssignRequest request) {

        log.info("Bulk assigning permissions to role: {}", request.getRoleId());

        List<RolePermissionResponse> response =
                rolePermissionService.bulkAssign(request);

        return ResponseEntity.ok(
                ApiResponse.success(
                        "Assigned permissions to role successfully", response));
    }

    @DeleteMapping("{id}")
    @PreAuthorize("hasRole('ADMIN') and hasAuthority('ROLE_PERMISSION_REVOKE')")
    @Operation(summary = "Thu hồi quyền khỏi vai trò, isActive=false")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable UUID id) {

        rolePermissionService.delete(id);

        return ResponseEntity.ok(
                ApiResponse.success(
                        "Revoked permission from role successfully.", null));
    }

    @GetMapping("/by-role/{roleId}")
    @PreAuthorize("hasRole('ADMIN') and hasAuthority('ROLE_PERMISSION_VIEW')")
    @Operation(summary = "Get all permissions assigned to a role")
    public ResponseEntity<ApiResponse<List<RolePermissionResponse>>> getByRoleId(
            @PathVariable UUID roleId) {

        List<RolePermissionResponse> response =
                rolePermissionService.getByRoleId(roleId);

        return ResponseEntity.ok(ApiResponse.success(response));
    }
}