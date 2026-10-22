package com.storehub.service;

import com.storehub.common.PageResponse;
import com.storehub.dto.request.RolePermissionBulkAssignRequest;
import com.storehub.dto.request.RolePermissionCreateRequest;
import com.storehub.dto.request.RolePermissionUpdateRequest;
import com.storehub.dto.response.RolePermissionResponse;

import java.util.*;

public interface RolePermissionService {
    void delete(UUID id);
    // convenience for authorization checks / role-permission-matrix screens
    List<RolePermissionResponse> getByRoleId(UUID roleId);

    List<RolePermissionResponse> bulkAssign(RolePermissionBulkAssignRequest request);
}
