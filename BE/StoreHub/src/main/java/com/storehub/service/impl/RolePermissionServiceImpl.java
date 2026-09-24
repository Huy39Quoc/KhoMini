package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.RolePermissionBulkAssignRequest;
import com.storehub.dto.request.RolePermissionCreateRequest;
import com.storehub.dto.request.RolePermissionUpdateRequest;
import com.storehub.dto.response.RolePermissionResponse;
import com.storehub.entity.Permission;
import com.storehub.entity.Role;
import com.storehub.entity.RolePermission;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.mapper.RolePermissionMapper;
import com.storehub.repository.PermissionRepository;
import com.storehub.repository.RolePermissionRepository;
import com.storehub.repository.RoleRepository;
import com.storehub.service.RolePermissionService;
import com.storehub.enums.ActivityAction;
import com.storehub.service.ActivityLogService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class RolePermissionServiceImpl implements RolePermissionService {

    private final RolePermissionRepository rolePermissionRepository;
    private final RoleRepository roleRepository;
    private final PermissionRepository permissionRepository;
    private final RolePermissionMapper rolePermissionMapper;
    private final ActivityLogService activityLogService;

    @Override
    public RolePermissionResponse getById(UUID id) {
        RolePermission rolePermission = rolePermissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.ROLE_PERMISSION_NOT_FOUND));
        return rolePermissionMapper.toResponse(rolePermission);
    }

    @Override
    public RolePermissionResponse create(RolePermissionCreateRequest request) {
        Role role = roleRepository.findById(request.getRoleId())
                .orElseThrow(() -> new AppException(ErrorCode.ROLE_NOT_FOUND));

        if (!Boolean.TRUE.equals(role.getIsActive())) {
            throw new AppException(ErrorCode.ROLE_INACTIVE);
        }

        Permission permission = permissionRepository.findById(request.getPermissionId())
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));

        if (!Boolean.TRUE.equals(permission.getIsActive())) {
            throw new AppException(ErrorCode.PERMISSION_INACTIVE);
        }

        Optional<RolePermission> existingOpt = rolePermissionRepository
                .findByRole_IdAndPermission_Id(role.getId(), permission.getId());

        if (existingOpt.isPresent()) {
            RolePermission existing = existingOpt.get();
            if (Boolean.TRUE.equals(existing.getIsActive())) {
                throw new AppException(ErrorCode.ROLE_PERMISSION_ALREADY_EXISTS);
            }
            existing.setIsActive(true);
            if (request.getDescription() != null) {
                existing.setDescription(request.getDescription());
            }
            RolePermission updated = rolePermissionRepository.save(existing);

            activityLogService.record(ActivityAction.ROLE_PERMISSION_ASSIGN, "ROLE_PERMISSION", updated.getId(),
                    "Re-activated permission " + permission.getName() + " for role " + role.getName(), null, role.getName());

            return rolePermissionMapper.toResponse(updated);
        }

        RolePermission rolePermission = RolePermission.builder()
                .role(role)
                .permission(permission)
                .isActive(true)
                .description(request.getDescription())
                .build();

        RolePermission saved = rolePermissionRepository.save(rolePermission);

        activityLogService.record(ActivityAction.ROLE_PERMISSION_ASSIGN, "ROLE_PERMISSION", saved.getId(),
                "Assigned permission " + permission.getName() + " to role " + role.getName(), null, role.getName());

        return rolePermissionMapper.toResponse(saved);
    }

    @Override
    public RolePermissionResponse update(UUID id, RolePermissionUpdateRequest request) {
        RolePermission rolePermission = rolePermissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.ROLE_PERMISSION_NOT_FOUND));

        Boolean oldActive = rolePermission.getIsActive();

        rolePermissionMapper.updateEntityFromRequest(request, rolePermission);
        RolePermission updated = rolePermissionRepository.save(rolePermission);

        ActivityAction action = (oldActive != null && oldActive && Boolean.FALSE.equals(updated.getIsActive()))
                ? ActivityAction.ROLE_PERMISSION_REVOKE
                : ActivityAction.ROLE_PERMISSION_ASSIGN;

        activityLogService.record(action, "ROLE_PERMISSION", updated.getId(),
                "Updated role permission assignment: role " + updated.getRole().getName()
                        + ", permission " + updated.getPermission().getName(),
                oldActive, updated.getIsActive());

        return rolePermissionMapper.toResponse(updated);
    }

    @Override
    public void delete(UUID id) {
        RolePermission rolePermission = rolePermissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.ROLE_PERMISSION_NOT_FOUND));
        rolePermission.setIsActive(false);
        rolePermissionRepository.save(rolePermission);

        activityLogService.record(ActivityAction.ROLE_PERMISSION_REVOKE, "ROLE_PERMISSION", rolePermission.getId(),
                "Revoked permission " + rolePermission.getPermission().getName() + " from role " + rolePermission.getRole().getName(), null, null);
    }

    @Override
    public PageResponse<RolePermissionResponse> getAll(
            UUID roleId, UUID permissionId, String search, Boolean isActive,
            int page, int size, String sortBy, String sortDir) {
        String resolvedSortBy = sortBy;
        if ("roleName".equalsIgnoreCase(sortBy)) {
            resolvedSortBy = "role.name";
        } else if ("permissionName".equalsIgnoreCase(sortBy)) {
            resolvedSortBy = "permission.name";
        } else if ("permissionGroup".equalsIgnoreCase(sortBy)) {
            resolvedSortBy = "permission.permissionGroup";
        }

        Sort sort = sortDir.equalsIgnoreCase("desc")
                ? Sort.by(resolvedSortBy).descending()
                : Sort.by(resolvedSortBy).ascending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<RolePermissionResponse> result = rolePermissionRepository
                .findAllWithFilters(roleId, permissionId, search, isActive, pageable)
                .map(rolePermissionMapper::toResponse);
        return PageResponse.from(result);
    }

    @Override
    public List<RolePermissionResponse> getByRoleId(UUID roleId) {
        if (!roleRepository.existsById(roleId)) {
            throw new AppException(ErrorCode.ROLE_NOT_FOUND);
        }
        return rolePermissionRepository.findAllByRole_Id(roleId)
                .stream()
                .map(rolePermissionMapper::toResponse)
                .toList();
    }

    @Override
    public List<RolePermissionResponse> bulkAssign(RolePermissionBulkAssignRequest request) {
        Role role = roleRepository.findById(request.getRoleId())
                .orElseThrow(() -> new AppException(ErrorCode.ROLE_NOT_FOUND));

        if (!Boolean.TRUE.equals(role.getIsActive())) {
            throw new AppException(ErrorCode.ROLE_INACTIVE);
        }

        List<UUID> rawPermissionIds = request.getPermissionIds();
        if (rawPermissionIds == null || rawPermissionIds.isEmpty()) {
            return Collections.emptyList();
        }

        List<UUID> permissionIds = rawPermissionIds.stream().distinct().toList();

        List<Permission> permissions = permissionRepository.findAllById(permissionIds);
        if (permissions.size() != permissionIds.size()) {
            throw new AppException(ErrorCode.PERMISSION_NOT_FOUND);
        }

        boolean hasInactive = permissions.stream().anyMatch(p -> !Boolean.TRUE.equals(p.getIsActive()));
        if (hasInactive) {
            throw new AppException(ErrorCode.PERMISSION_INACTIVE);
        }

        List<RolePermission> existingList = rolePermissionRepository
                .findAllByRole_IdAndPermission_IdIn(role.getId(), permissionIds);

        Map<UUID, RolePermission> existingMap = existingList.stream()
                .collect(Collectors.toMap(rp -> rp.getPermission().getId(), rp -> rp, (a, b) -> a));

        List<RolePermission> toSave = new ArrayList<>();

        for (Permission permission : permissions) {
            RolePermission rp = existingMap.get(permission.getId());
            if (rp != null) {
                if (!Boolean.TRUE.equals(rp.getIsActive())) {
                    rp.setIsActive(true);
                }
                toSave.add(rp);
            } else {
                RolePermission newRp = RolePermission.builder()
                        .role(role)
                        .permission(permission)
                        .isActive(true)
                        .build();
                toSave.add(newRp);
            }
        }

        List<RolePermission> saved = rolePermissionRepository.saveAll(toSave);

        activityLogService.record(ActivityAction.ROLE_PERMISSION_ASSIGN, "ROLE_PERMISSION", role.getId(),
                "Bulk assigned " + saved.size() + " permissions to role: " + role.getName(), null, role.getName());

        return saved.stream()
                .map(rolePermissionMapper::toResponse)
                .toList();
    }
}
