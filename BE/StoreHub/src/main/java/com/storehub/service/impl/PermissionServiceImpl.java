package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
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
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
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
    public PermissionResponse create(PermissionCreateRequest request) {
        String trimmedName = request.getName() != null ? request.getName().trim() : "";
        String trimmedGroup = request.getPermissionGroup() != null ? request.getPermissionGroup().trim() : "";

        if (permissionRepository.existsByName(trimmedName)) {
            throw new AppException(ErrorCode.PERMISSION_NAME_EXISTED);
        }
        Permission permission = permissionMapper.toEntity(request);
        permission.setName(trimmedName);
        permission.setPermissionGroup(trimmedGroup);
        Permission saved = permissionRepository.save(permission);

        activityLogService.record(ActivityAction.PERMISSION_CREATE, "PERMISSION", saved.getId(),
                "Created permission: " + saved.getName(), null, saved.getName());

        return permissionMapper.toResponse(saved);
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
    public void delete(UUID id) {
        Permission permission = permissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));

        // Cascade delete any role-permission associations to prevent foreign key violation
        rolePermissionRepository.deleteAllByPermission_Id(permission.getId());

        permissionRepository.deleteById(permission.getId());

        activityLogService.record(ActivityAction.PERMISSION_DELETE, "PERMISSION", permission.getId(),
                "Deleted permission: " + permission.getName(), permission.getName(), null);
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
