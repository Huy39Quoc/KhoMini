package com.storehub.service;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.RolePermissionBulkAssignRequest;
import com.storehub.dto.request.RolePermissionCreateRequest;
import com.storehub.dto.request.RolePermissionUpdateRequest;
import com.storehub.dto.response.RolePermissionResponse;

import java.util.*;

public interface RolePermissionService {
    RolePermissionResponse getById(UUID id);
    RolePermissionResponse create(RolePermissionCreateRequest request);
    RolePermissionResponse update(UUID id, RolePermissionUpdateRequest request);
    void delete(UUID id);
    PageResponse<RolePermissionResponse> getAll(
            UUID roleId, UUID permissionId, String search, Boolean isActive,
            int page, int size, String sortBy, String sortDir);

    // convenience for authorization checks / role-permission-matrix screens
    List<RolePermissionResponse> getByRoleId(UUID roleId);

    List<RolePermissionResponse> bulkAssign(RolePermissionBulkAssignRequest request);
}
