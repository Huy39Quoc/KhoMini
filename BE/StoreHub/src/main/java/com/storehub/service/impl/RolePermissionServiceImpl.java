package com.storehub.service.impl;

import com.storehub.common.PageResponse;
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
    public void delete(UUID id) {
        RolePermission rolePermission = rolePermissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.ROLE_PERMISSION_NOT_FOUND));
        rolePermission.setIsActive(false);
        rolePermissionRepository.save(rolePermission);

        activityLogService.record(ActivityAction.ROLE_PERMISSION_REVOKE, "ROLE_PERMISSION", rolePermission.getId(),
                "Revoked permission " + rolePermission.getPermission().getName() + " from role " + rolePermission.getRole().getName(), null, null);
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
