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

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class PermissionServiceImpl implements PermissionService {

    private static final Set<String> SYSTEM_PERMISSIONS = Set.of(
            "USER_VIEW", "USER_CREATE", "USER_UPDATE", "USER_DELETE",
            "ROLE_VIEW", "ROLE_CREATE", "ROLE_UPDATE", "ROLE_DELETE",
            "FACILITY_VIEW", "FACILITY_CREATE", "FACILITY_UPDATE", "FACILITY_DELETE",
            "STORAGE_UNIT_VIEW", "STORAGE_UNIT_CREATE", "STORAGE_UNIT_UPDATE", "STORAGE_UNIT_DELETE",
            "BOOKING_VIEW", "BOOKING_CREATE", "BOOKING_UPDATE", "BOOKING_CANCEL",
            "PAYMENT_VIEW", "PAYMENT_CREATE",
            "SUPPORT_VIEW", "SUPPORT_CREATE", "SUPPORT_UPDATE",
            "REPORT_VIEW",
            "POLICY_VIEW", "POLICY_UPDATE"
    );

    private final PermissionRepository permissionRepository;
    private final RolePermissionRepository rolePermissionRepository;
    private final PermissionMapper permissionMapper;

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

        return permissionMapper.toResponse(saved);
    }

    @Override
    public PermissionResponse update(UUID id, PermissionUpdateRequest request) {
        Permission permission = permissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));

        String trimmedName = request.getName() != null ? request.getName().trim() : permission.getName();
        String trimmedGroup = request.getPermissionGroup() != null ? request.getPermissionGroup().trim() : permission.getPermissionGroup();

        // Protect default system permissions from being renamed
        if (SYSTEM_PERMISSIONS.contains(permission.getName().toUpperCase())
                && !permission.getName().equalsIgnoreCase(trimmedName)) {
            throw new AppException(ErrorCode.CANNOT_MODIFY_SYSTEM_PERMISSION);
        }

        if (permissionRepository.existsByNameAndIdNot(trimmedName, permission.getId())) {
            throw new AppException(ErrorCode.PERMISSION_NAME_EXISTED);
        }

        permissionMapper.updateEntityFromRequest(request, permission);
        permission.setName(trimmedName);
        permission.setPermissionGroup(trimmedGroup);
        Permission updated = permissionRepository.save(permission);
        return permissionMapper.toResponse(updated);
    }

    @Override
    public void delete(UUID id) {
        Permission permission = permissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));

        // Protect default system permissions from deletion
        if (SYSTEM_PERMISSIONS.contains(permission.getName().toUpperCase())) {
            throw new AppException(ErrorCode.CANNOT_DELETE_SYSTEM_PERMISSION);
        }

        // Cascade delete any role-permission associations to prevent foreign key violation
        rolePermissionRepository.deleteAllByPermission_Id(permission.getId());

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
