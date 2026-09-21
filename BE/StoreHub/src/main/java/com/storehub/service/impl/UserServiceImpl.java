package com.storehub.service.impl;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.UserCreateRequest;
import com.storehub.dto.request.UserUpdateRequest;
import com.storehub.dto.response.UserResponse;
import com.storehub.entity.Role;
import com.storehub.entity.User;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.mapper.UserMapper;
import com.storehub.repository.RoleRepository;
import com.storehub.repository.UserRepository;
import com.storehub.enums.ActivityAction;
import com.storehub.service.ActivityLogService;
import com.storehub.service.UserService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final ActivityLogService activityLogService;


    @Override
    public UserResponse create(UserCreateRequest request) {

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new AppException(ErrorCode.EMAIL_ALREADY_EXISTS);
        }
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new AppException(ErrorCode.USER_ALREADY_EXISTS);
        }

        Role role;
        if (request.getRoleId() != null) {
            role = roleRepository.findById(request.getRoleId())
                    .orElseThrow(() -> new AppException(ErrorCode.ROLE_NOT_FOUND));
        } else {
            role = roleRepository.findByName("CUSTOMER")
                    .orElseThrow(() -> new AppException(ErrorCode.ROLE_NOT_FOUND));
        }

        User user = User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName())
                .phone(request.getPhone())
                .role(role)
                .isActive(true)
                .build();

        User saved = userRepository.save(user);
        activityLogService.record(ActivityAction.USER_CREATE, "USER", saved.getId(),
                "Created user: " + saved.getUsername(), null, saved.getEmail());
        return userMapper.toResponse(saved);
    }


    @Override
    public UserResponse update(UUID id, UserUpdateRequest request) {

        User user = userRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        // Check username duplicate — exclude current user
        if (request.getUsername() != null
                && userRepository.existsByUsernameAndIdNot(request.getUsername(), id)) {
            throw new AppException(ErrorCode.USER_ALREADY_EXISTS);
        }

        // Update role if provided
        boolean roleChanged = false;
        if (request.getRoleId() != null) {
            Role role = roleRepository.findById(request.getRoleId())
                    .orElseThrow(() -> new AppException(ErrorCode.ROLE_NOT_FOUND));
            user.setRole(role);
            roleChanged = true;
        }

        userMapper.updateEntityFromRequest(request, user);
        User updated = userRepository.save(user);

        ActivityAction action = roleChanged ? ActivityAction.USER_ASSIGN_ROLE : ActivityAction.USER_UPDATE;
        activityLogService.record(action, "USER", updated.getId(),
                "Updated user: " + updated.getUsername(), null, updated.getEmail());

        return userMapper.toResponse(updated);
    }


    @Override
    public void delete(UUID id) {

        if (!userRepository.existsById(id)) {
            throw new AppException(ErrorCode.USER_NOT_FOUND);
        }

        userRepository.deleteById(id);
        log.info("User deleted successfully with id: {}", id);

        activityLogService.record(ActivityAction.USER_DEACTIVATE, "USER", id,
                "Deleted user with id: " + id, null, null);
    }


    @Override
    @Transactional(readOnly = true)
    public UserResponse getById(UUID id) {

        User user = userRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        return userMapper.toResponse(user);
    }


    @Override
    @Transactional(readOnly = true)
    public PageResponse<UserResponse> findAllWithFilters(
            String search,
            Boolean isActive,
            int page,
            int size,
            String sortBy,
            String sortDir
    ) {

        Sort sort = sortDir.equalsIgnoreCase("desc")
                ? Sort.by(sortBy).descending()
                : Sort.by(sortBy).ascending();

        Pageable pageable = PageRequest.of(page, size, sort);

        Page<UserResponse> result = userRepository
                .findAllWithFilters(search, isActive, pageable)
                .map(userMapper::toResponse);

        return PageResponse.from(result);
    }

    @Override
    public UserResponse toggleActive(UUID id) {

        User user = userRepository.findById(id)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        boolean oldStatus = user.getIsActive();
        user.setIsActive(!oldStatus);
        User updated = userRepository.save(user);

        ActivityAction action = updated.getIsActive() ? ActivityAction.USER_ACTIVATE : ActivityAction.USER_DEACTIVATE;
        activityLogService.record(action, "USER", updated.getId(),
                "Toggled user active status for " + updated.getUsername() + " to: " + updated.getIsActive(),
                oldStatus, updated.getIsActive());

        return userMapper.toResponse(updated);
    }
}