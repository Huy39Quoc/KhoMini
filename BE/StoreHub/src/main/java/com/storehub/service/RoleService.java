package com.storehub.service;
import com.storehub.common.PageResponse;
import com.storehub.dto.request.RoleCreateRequest;
import com.storehub.dto.request.RoleUpdateRequest;
import com.storehub.dto.response.RoleResponse;

import java.util.*;

public interface RoleService {
        RoleResponse getById(UUID id);
        RoleResponse update(UUID id, RoleUpdateRequest request);
        PageResponse<RoleResponse> getAll(String search, Boolean isActive, int page, int size, String sortBy, String sortDir);
}
