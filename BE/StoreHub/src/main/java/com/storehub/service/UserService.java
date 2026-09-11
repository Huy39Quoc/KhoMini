package com.storehub.service;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.UserCreateRequest;
import com.storehub.dto.request.UserUpdateRequest;
import com.storehub.dto.response.UserResponse;

import java.util.UUID;

public interface UserService {
    UserResponse create(UserCreateRequest request);
    UserResponse update(UUID id, UserUpdateRequest request);
    void delete(UUID id);
    UserResponse getById(UUID id);
    PageResponse<UserResponse> findAllWithFilters(String search, Boolean isActive, int page, int size, String sortBy, String sortDir);
    UserResponse toggleActive(UUID id);
}
