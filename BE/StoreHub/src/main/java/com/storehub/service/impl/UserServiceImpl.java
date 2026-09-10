package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.UserCreateRequest;
import com.storehub.dto.request.UserUpdateRequest;
import com.storehub.dto.response.UserResponse;
import com.storehub.service.UserService;
import jakarta.transaction.Transactional;
import lombok.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.*;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class UserServiceImpl implements UserService {
    @Override
    public UserResponse create(UserCreateRequest request) {
        return null;
    }

    @Override
    public UserResponse update(UUID id, UserUpdateRequest request) {
        return null;
    }

    @Override
    public void delete(UUID id) {

    }

    @Override
    public UserResponse getById(UUID id) {
        return null;
    }

    @Override
    public PageResponse<UserResponse> findAllWithFilters(String search, Boolean isActive, int page, int size, String sortBy, String sortDir) {
        return null;
    }
}
