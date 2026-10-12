package com.storehub.service;

import com.storehub.dto.request.RefreshTokenRequest;
import com.storehub.entity.RefreshToken;
import com.storehub.entity.Role;
import com.storehub.entity.User;
import com.storehub.enums.TokenType;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.mapper.UserMapper;
import com.storehub.repository.RefreshTokenRepository;
import com.storehub.repository.RoleRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.AuthServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RefreshTokenAccessTest {
    @Mock UserRepository userRepository;
    @Mock RoleRepository roleRepository;
    @Mock RefreshTokenRepository refreshTokenRepository;
    @Mock UserMapper userMapper;
    @Mock JwtService jwtService;
    @Mock PasswordEncoder passwordEncoder;
    @Mock AuthenticationManager authenticationManager;
    @Mock EmailService emailService;
    @Mock ActivityLogService activityLogService;
    @InjectMocks AuthServiceImpl authService;

    @Test
    void disabledUserCannotRefresh() {
        User user = User.builder()
                .isActive(false)
                .role(Role.builder().name("CUSTOMER").build())
                .build();
        assertRejected(user, ErrorCode.USER_INACTIVE);
    }

    @Test
    void disabledRoleCannotRefresh() {
        User user = User.builder()
                .isActive(true)
                .role(Role.builder().name("CUSTOMER").isActive(false).build())
                .build();
        assertRejected(user, ErrorCode.ROLE_INACTIVE);
    }

    private void assertRejected(User user, ErrorCode expected) {
        RefreshToken stored = RefreshToken.builder()
                .user(user)
                .token("refresh-token")
                .type(TokenType.REFRESH)
                .expiredAt(LocalDateTime.now().plusHours(1))
                .build();
        when(refreshTokenRepository.findByTokenAndTypeAndRevokedFalse(
                "refresh-token", TokenType.REFRESH))
                .thenReturn(Optional.of(stored));

        AppException error = assertThrows(AppException.class,
                () -> authService.refreshToken(new RefreshTokenRequest("refresh-token")));
        assertEquals(expected, error.getErrorCode());
        verify(jwtService, never()).generateAccessToken(user);
    }
}
