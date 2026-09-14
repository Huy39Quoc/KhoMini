package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.PermissionCreateRequest;
import com.storehub.dto.request.PermissionUpdateRequest;
import com.storehub.dto.response.PermissionResponse;
import com.storehub.entity.Permission;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.mapper.PermissionMapper;
import com.storehub.repository.PermissionRepository;
import com.storehub.service.PermissionService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;
import lombok.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.*;

import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class PermissionServiceImpl implements PermissionService {

    private final PermissionRepository permissionRepository;
    private final PermissionMapper permissionMapper;

    @Override
    public PermissionResponse getById(UUID id) {
        Permission permission = permissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));
        return permissionMapper.toResponse(permission);
    }

    @Override
    public PermissionResponse create(PermissionCreateRequest request) {
        if (permissionRepository.existsByName(request.getName())) {
            throw new AppException(ErrorCode.PERMISSION_NAME_EXISTED);
        }
        if (permissionRepository.existsByPermissionGroup(request.getPermissionGroup())) {
            throw new AppException(ErrorCode.PERMISSION_GROUP_EXISTED);
        }
        Permission permission = permissionMapper.toEntity(request);
        Permission saved = permissionRepository.save(permission);

        return permissionMapper.toResponse(saved);
    }

    @Override
    public PermissionResponse update(UUID id, PermissionUpdateRequest request) {
        Permission permission = permissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));

        if (permissionRepository.existsByNameAndIdNot(request.getName(), permission.getId())) {
            throw new AppException(ErrorCode.PERMISSION_NAME_EXISTED);
        }
        if (permissionRepository.existsByPermissionGroupAndIdNot(request.getPermissionGroup(), permission.getId())) {
            throw new AppException(ErrorCode.PERMISSION_GROUP_EXISTED);
        }

        permissionMapper.updateEntityFromRequest(request, permission);
        Permission updated = permissionRepository.save(permission);
        return permissionMapper.toResponse(updated);
    }

    @Override
    public void delete(UUID id) {
        Permission permission = permissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));
        permissionRepository.deleteById(permission.getId());
    }

    @Override
    public PageResponse<PermissionResponse> getAll
            (String search, Boolean isActive, int page, int size, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc")
                ? Sort.by(sortBy).descending()
                : Sort.by(sortBy).ascending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<PermissionResponse> result = permissionRepository.findAllWithFilters(search, isActive, pageable)
                .map(permissionMapper::toResponse);
        return PageResponse.from(result);
    }
}
