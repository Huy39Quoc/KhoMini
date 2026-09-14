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

        Permission permission = permissionRepository.findById(request.getPermissionId())
                .orElseThrow(() -> new AppException(ErrorCode.PERMISSION_NOT_FOUND));

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
            return rolePermissionMapper.toResponse(updated);
        }

        RolePermission rolePermission = RolePermission.builder()
                .role(role)
                .permission(permission)
                .isActive(true)
                .description(request.getDescription())
                .build();

        RolePermission saved = rolePermissionRepository.save(rolePermission);
        return rolePermissionMapper.toResponse(saved);
    }

    @Override
    public RolePermissionResponse update(UUID id, RolePermissionUpdateRequest request) {
        RolePermission rolePermission = rolePermissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.ROLE_PERMISSION_NOT_FOUND));

        rolePermissionMapper.updateEntityFromRequest(request, rolePermission);
        RolePermission updated = rolePermissionRepository.save(rolePermission);
        return rolePermissionMapper.toResponse(updated);
    }

    @Override
    public void delete(UUID id) {
        RolePermission rolePermission = rolePermissionRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.ROLE_PERMISSION_NOT_FOUND));
        rolePermissionRepository.deleteById(rolePermission.getId());
    }

    @Override
    public PageResponse<RolePermissionResponse> getAll(
            UUID roleId, UUID permissionId, String search, Boolean isActive,
            int page, int size, String sortBy, String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("desc")
                ? Sort.by(sortBy).descending()
                : Sort.by(sortBy).ascending();
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

        List<UUID> permissionIds = request.getPermissionIds();
        if (permissionIds == null || permissionIds.isEmpty()) {
            return Collections.emptyList();
        }

        List<Permission> permissions = permissionRepository.findAllById(permissionIds);
        if (permissions.isEmpty()) {
            return Collections.emptyList();
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
        return saved.stream()
                .map(rolePermissionMapper::toResponse)
                .toList();
    }
}
