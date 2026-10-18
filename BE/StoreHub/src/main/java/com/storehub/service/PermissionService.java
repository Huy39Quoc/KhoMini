package com.storehub.service;

import com.storehub.common.PageResponse;
import com.storehub.dto.request.PermissionCreateRequest;
import com.storehub.dto.request.PermissionUpdateRequest;
import com.storehub.dto.response.PermissionResponse;

import java.util.*;

public interface PermissionService {
    PermissionResponse getById(UUID id);
    PermissionResponse update(UUID id, PermissionUpdateRequest request);
    PageResponse<PermissionResponse> getAll(String search, Boolean isActive, int page, int size, String sortBy, String sortDir);
}
