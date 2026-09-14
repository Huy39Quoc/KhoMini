package com.storehub.service;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.PermissionCreateRequest;
import com.storehub.dto.request.PermissionUpdateRequest;
import com.storehub.dto.response.PermissionResponse;

import java.util.*;

public interface PermissionService {
    PermissionResponse getById(UUID id);
    PermissionResponse create(PermissionCreateRequest request);
    PermissionResponse update(UUID id, PermissionUpdateRequest request);
    void delete(UUID id);
    PageResponse<PermissionResponse> getAll(String search, Boolean isActive, int page, int size, String sortBy, String sortDir);
}
