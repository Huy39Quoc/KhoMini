package com.storehub.service;

import com.storehub.dto.request.*;
import com.storehub.entity.*;
import com.storehub.enums.TokenType;
import com.storehub.exception.*;
import com.storehub.mapper.UserMapper;
import com.storehub.repository.*;
import com.storehub.service.impl.AuthServiceImpl;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.time.LocalDateTime;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthSessionLifecycleTest {
    @Mock UserRepository users;
    @Mock RoleRepository roles;
    @Mock RefreshTokenRepository tokens;
    @Mock UserMapper mapper;
    @Mock JwtService jwt;
    @Mock PasswordEncoder encoder;
    @Mock AuthenticationManager authentication;
    @Mock EmailService email;
    @Mock ActivityLogService logs;
    @InjectMocks AuthServiceImpl auth;
    User user;
    RefreshToken session;

    @BeforeEach void setup() {
        user = User.builder().email("customer@test.com").password("old-hash")
                .role(Role.builder().name("CUSTOMER").build()).build(); user.setId(UUID.randomUUID());
        session = RefreshToken.builder().user(user).token("refresh").type(TokenType.REFRESH)
                .expiredAt(LocalDateTime.now().plusDays(1)).build(); session.setId(UUID.randomUUID());
    }

    @Test void refreshLocksOwnerBeforeRereadingTheTokenAndKeepsTheSameSessionId() {
        when(tokens.findActiveTokenUserId("refresh", TokenType.REFRESH)).thenReturn(Optional.of(user.getId()));
        when(users.lockAuthUserById(user.getId())).thenReturn(Optional.of(user));
        when(tokens.findByTokenAndTypeAndRevokedFalse("refresh", TokenType.REFRESH)).thenReturn(Optional.of(session));
        when(jwt.isTokenValid("refresh")).thenReturn(true);
        when(jwt.generateAccessToken(user, session.getId())).thenReturn("new-access");
        var response = auth.refreshToken(new RefreshTokenRequest("refresh"));
        assertEquals("new-access", response.getAccessToken());
        var order = inOrder(users, tokens, jwt);
        order.verify(users).lockAuthUserById(user.getId());
        order.verify(tokens).findByTokenAndTypeAndRevokedFalse("refresh", TokenType.REFRESH);
        order.verify(tokens).save(session);
        order.verify(jwt).generateAccessToken(user, session.getId());
    }

    @Test void aRefreshWaitingForLogoutMustRereadAndRejectTheRevokedToken() {
        when(tokens.findActiveTokenUserId("refresh", TokenType.REFRESH)).thenReturn(Optional.of(user.getId()));
        when(users.lockAuthUserById(user.getId())).thenReturn(Optional.of(user));
        when(tokens.findByTokenAndTypeAndRevokedFalse("refresh", TokenType.REFRESH)).thenReturn(Optional.empty());
        assertEquals(ErrorCode.INVALID_REFRESH_TOKEN, assertThrows(AppException.class,
                () -> auth.refreshToken(new RefreshTokenRequest("refresh"))).getErrorCode());
        verify(tokens, never()).save(any()); verifyNoInteractions(jwt);
    }

    @Test void passwordChangeRevokesEveryLoginSessionUnderTheUserLock() {
        when(users.lockAuthUserByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(encoder.matches("old-password", "old-hash")).thenReturn(true);
        when(encoder.encode("new-password")).thenReturn("new-hash");
        ChangePasswordRequest request = new ChangePasswordRequest(); request.setOldPassword("old-password");
        request.setNewPassword("new-password"); request.setConfirmPassword("new-password");
        auth.changePassword(user.getEmail(), request);
        assertEquals("new-hash", user.getPassword());
        var order = inOrder(users, tokens);
        order.verify(users).lockAuthUserByEmail(user.getEmail());
        order.verify(users).save(user);
        order.verify(tokens).revokeAllUserTokens(user);
    }

    @Test void loginPersistsTheSessionBeforeIssuingAccessAndUsesActualRefreshExpiry() {
        when(users.lockAuthUserByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(jwt.generateRefreshToken(user)).thenReturn("refresh");
        LocalDateTime expiry = LocalDateTime.now().plusHours(2);
        when(jwt.extractExpiration("refresh")).thenReturn(expiry);
        when(tokens.save(any())).thenAnswer(call -> {
            RefreshToken saved = call.getArgument(0); saved.setId(session.getId()); return saved;
        });
        when(jwt.generateAccessToken(user, session.getId())).thenReturn("access");
        LoginRequest request = new LoginRequest(); request.setEmail(user.getEmail()); request.setPassword("password");
        assertEquals("access", auth.login(request).getAccessToken());
        var stored = ArgumentCaptor.forClass(RefreshToken.class);
        verify(tokens).save(stored.capture());
        assertEquals(expiry, stored.getValue().getExpiredAt());
        var order = inOrder(tokens, jwt);
        order.verify(tokens).save(any());
        order.verify(jwt).generateAccessToken(user, session.getId());
    }
}
