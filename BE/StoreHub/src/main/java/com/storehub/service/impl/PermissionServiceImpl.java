package com.storehub.service.impl;

import com.storehub.common.PageResponse;
import com.storehub.dto.request.PermissionCreateRequest;
import com.storehub.dto.request.PermissionUpdateRequest;
import com.storehub.dto.response.PermissionResponse;
import com.storehub.entity.Permission;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.mapper.PermissionMapper;
import com.storehub.repository.RolePermissionRepository;
import com.storehub.repository.PermissionRepository;
import com.storehub.service.PermissionService;
import com.storehub.util.PaginationUtils;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.transaction.annotation.Transactional;
import lombok.*;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.*;

import java.util.*;
import com.storehub.enums.ActivityAction;
import com.storehub.service.ActivityLogService;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class PermissionServiceImpl implements PermissionService {

    private final PermissionRepository permissionRepository;
    private final RolePermissionRepository rolePermissionRepository;
    private final PermissionMapper permissionMapper;
    private final ActivityLogService activityLogService;

    @Override
    public PermissionResponse getById(UUID id) {
        Permission permission = permissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));
        return permissionMapper.toResponse(permission);
    }

    @Override
    public PermissionResponse update(UUID id, PermissionUpdateRequest request) {
        Permission permission = permissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));

        String trimmedName = request.getName() != null ? request.getName().trim() : permission.getName();
        String trimmedGroup = request.getPermissionGroup() != null ? request.getPermissionGroup().trim() : permission.getPermissionGroup();

        if (permissionRepository.existsByNameAndIdNot(trimmedName, permission.getId())) {
            throw new AppException(ErrorCode.PERMISSION_NAME_EXISTED);
        }

        String oldName = permission.getName();
        permissionMapper.updateEntityFromRequest(request, permission);
        permission.setName(trimmedName);
        permission.setPermissionGroup(trimmedGroup);
        Permission updated = permissionRepository.save(permission);

        activityLogService.record(ActivityAction.PERMISSION_UPDATE, "PERMISSION", updated.getId(),
                "Updated permission: " + updated.getName(), oldName, updated.getName());

        return permissionMapper.toResponse(updated);
    }

    @Override
    public PageResponse<PermissionResponse> getAll
            (String search, Boolean isActive, int page, int size, String sortBy, String sortDir) {
        Pageable pageable = PaginationUtils.pageRequest(page, size, sortBy, sortDir, Map.of(
                "createdAt", "createdAt",
                "name", "name",
                "permissionGroup", "permissionGroup",
                "isActive", "isActive"
        ));
        Page<PermissionResponse> result = permissionRepository.findAllWithFilters(search, isActive, pageable)
                .map(permissionMapper::toResponse);
        return PageResponse.from(result);
    }
}
