package com.storehub.service;

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
import com.storehub.service.impl.UserServiceImpl;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceRoleSecurityTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private RoleRepository roleRepository;

    @Mock
    private UserMapper userMapper;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private ActivityLogService activityLogService;

    @InjectMocks
    private UserServiceImpl userService;

    @BeforeEach
    void setUp() {
        SecurityContextHolder.clearContext();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void testCreate_NonAdminCannotSpecifyRoleId() {
        // Authenticated as CUSTOMER
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                "customer@test.com", "pass", List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        UserCreateRequest request = UserCreateRequest.builder()
                .username("newuser")
                .email("new@test.com")
                .password("password123")
                .fullName("New User")
                .phone("0901234567")
                .roleId(UUID.randomUUID()) // attempts to assign role
                .build();

        AppException ex = assertThrows(AppException.class, () -> userService.create(request));
        assertEquals(ErrorCode.FORBIDDEN, ex.getErrorCode());
    }

    @Test
    void testCreate_AdminCanSpecifyRoleId() {
        // Authenticated as ADMIN
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                "admin@test.com", "pass", List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        UUID roleId = UUID.randomUUID();
        Role role = Role.builder().name("STAFF").build();
        role.setId(roleId);

        UserCreateRequest request = UserCreateRequest.builder()
                .username("newstaff")
                .email("staff@test.com")
                .password("password123")
                .fullName("New Staff")
                .phone("0901234567")
                .roleId(roleId)
                .build();

        when(userRepository.existsByEmail(request.getEmail())).thenReturn(false);
        when(userRepository.existsByUsername(request.getUsername())).thenReturn(false);
        when(roleRepository.findById(roleId)).thenReturn(Optional.of(role));
        when(passwordEncoder.encode(request.getPassword())).thenReturn("encodedPass");
        when(userRepository.save(any(User.class))).thenAnswer(i -> {
            User u = i.getArgument(0);
            u.setId(UUID.randomUUID());
            return u;
        });
        when(userMapper.toResponse(any(User.class))).thenReturn(UserResponse.builder().username("newstaff").build());

        UserResponse response = userService.create(request);
        assertNotNull(response);
        assertEquals("newstaff", response.getUsername());
    }

    @Test
    void testCreate_WithoutRoleId_DefaultsToCustomer() {
        // No roleId provided, even if unauthenticated or non-admin
        Role customerRole = Role.builder().name("CUSTOMER").build();
        customerRole.setId(UUID.randomUUID());

        UserCreateRequest request = UserCreateRequest.builder()
                .username("customeruser")
                .email("cust@test.com")
                .password("password123")
                .fullName("Customer User")
                .phone("0901234567")
                .roleId(null)
                .build();

        when(userRepository.existsByEmail(request.getEmail())).thenReturn(false);
        when(userRepository.existsByUsername(request.getUsername())).thenReturn(false);
        when(roleRepository.findByName("CUSTOMER")).thenReturn(Optional.of(customerRole));
        when(passwordEncoder.encode(request.getPassword())).thenReturn("encodedPass");
        when(userRepository.save(any(User.class))).thenAnswer(i -> {
            User u = i.getArgument(0);
            u.setId(UUID.randomUUID());
            return u;
        });
        when(userMapper.toResponse(any(User.class))).thenReturn(UserResponse.builder().username("customeruser").build());

        UserResponse response = userService.create(request);
        assertNotNull(response);
        assertEquals("customeruser", response.getUsername());
    }

    @Test
    void testUpdate_NonAdminCannotChangeRole() {
        UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                "customer@test.com", "pass", List.of(new SimpleGrantedAuthority("ROLE_CUSTOMER"))
        );
        SecurityContextHolder.getContext().setAuthentication(auth);

        UUID userId = UUID.randomUUID();
        User existingUser = User.builder().username("cust").email("cust@test.com").isActive(true).build();
        existingUser.setId(userId);

        UserUpdateRequest request = UserUpdateRequest.builder()
                .roleId(UUID.randomUUID()) // attempts to escalate role
                .build();

        when(userRepository.findById(userId)).thenReturn(Optional.of(existingUser));

        AppException ex = assertThrows(AppException.class, () -> userService.update(userId, request));
        assertEquals(ErrorCode.FORBIDDEN, ex.getErrorCode());
    }
}
