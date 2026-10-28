package com.storehub.service.impl;

import com.storehub.dto.request.*;
import com.storehub.dto.response.AuthResponse;
import com.storehub.dto.response.UserResponse;
import com.storehub.entity.RefreshToken;
import com.storehub.entity.Role;
import com.storehub.entity.User;
import com.storehub.enums.*;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.mapper.UserMapper;
import com.storehub.repository.RefreshTokenRepository;
import com.storehub.repository.RoleRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.AuthService;
import com.storehub.service.EmailService;
import com.storehub.service.JwtService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final UserMapper userMapper;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final EmailService emailService;
    private final com.storehub.service.ActivityLogService activityLogService;


    @Override
    public AuthResponse register(RegisterRequest request) {

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new AppException(ErrorCode.EMAIL_ALREADY_EXISTS);
        }
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new AppException(ErrorCode.USER_ALREADY_EXISTS);
        }

        Role studentRole = roleRepository.findByName("CUSTOMER")
                .orElseThrow(() -> new AppException(ErrorCode.ROLE_NOT_FOUND));

        User user = User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName())
                .phone(request.getPhone())
                .role(studentRole)
                .isActive(true)
                .build();

        User saved = userRepository.save(user);
        log.info("User registered successfully with id: {}", saved.getId());

        activityLogService.record(saved.getId(), ActivityAction.USER_CREATE, "USER", saved.getId(),
                "Customer self-registered account: " + saved.getUsername(), null, saved.getEmail());

        emailService.sendWelcomeEmail(saved.getEmail(), saved.getFullName());

        UserResponse userResponse = userMapper.toResponse(saved);

        return AuthResponse.builder()
                .user(userResponse)
                .build();
    }


    @Override
    public AuthResponse login(LoginRequest request) {
        // Serialize credential checks and session changes with password reset,
        // refresh and logout for this account.
        User user = userRepository.lockAuthUserByEmail(request.getEmail()).orElseThrow(() -> {
            activityLogService.recordLogin(null, request.getEmail(), false, "Invalid credentials");
            return new AppException(ErrorCode.INVALID_CREDENTIALS);
        });
        try {
            authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(
                            request.getEmail(),
                            request.getPassword()
                    )
            );
        } catch (BadCredentialsException e) {
            User attemptedUser = userRepository.findByEmail(request.getEmail()).orElse(null);
            activityLogService.recordLogin(
                    attemptedUser != null ? attemptedUser.getId() : null,
                    request.getEmail(),
                    false,
                    "Invalid credentials (wrong password)"
            );
            throw new AppException(ErrorCode.INVALID_CREDENTIALS);
        }

        // Revoke old refresh tokens
        refreshTokenRepository.revokeAllUserTokensByType(user, TokenType.REFRESH);

        activityLogService.recordLogin(user.getId(), request.getEmail(), true, null);

        return buildAuthResponse(user);
    }


    @Override
    public void logout(String refreshTokenValue) {
        lockTokenUser(refreshTokenValue, TokenType.REFRESH, ErrorCode.INVALID_REFRESH_TOKEN);

        RefreshToken refreshToken = refreshTokenRepository
                .findByTokenAndTypeAndRevokedFalse(refreshTokenValue, TokenType.REFRESH)
                .orElseThrow(() -> new AppException(ErrorCode.INVALID_REFRESH_TOKEN));

        refreshToken.setRevoked(true);
        refreshTokenRepository.save(refreshToken);

        if (refreshToken.getUser() != null) {
            activityLogService.recordLogout(refreshToken.getUser().getId());
        }

    }


    @Override
    public AuthResponse refreshToken(RefreshTokenRequest request) {
        User user = lockTokenUser(request.getRefreshToken(), TokenType.REFRESH, ErrorCode.INVALID_REFRESH_TOKEN);

        RefreshToken storedToken = refreshTokenRepository
                .findByTokenAndTypeAndRevokedFalse(request.getRefreshToken(), TokenType.REFRESH)
                .orElseThrow(() -> new AppException(ErrorCode.INVALID_REFRESH_TOKEN));

        if (storedToken.getExpiredAt().isBefore(LocalDateTime.now())) {
            storedToken.setRevoked(true);
            refreshTokenRepository.save(storedToken);
            throw new AppException(ErrorCode.TOKEN_EXPIRED);
        }

        if (user == null || !Boolean.TRUE.equals(user.getIsActive())) {
            throw new AppException(ErrorCode.USER_INACTIVE);
        }
        if (user.getRole() == null
                || !Boolean.TRUE.equals(user.getRole().getIsActive())) {
            throw new AppException(ErrorCode.ROLE_INACTIVE);
        }

        if (!jwtService.isTokenValid(request.getRefreshToken())) {
            throw new AppException(ErrorCode.TOKEN_EXPIRED);
        }
        storedToken.setLastUsedAt(LocalDateTime.now());
        refreshTokenRepository.save(storedToken);

        String newAccessToken = jwtService.generateAccessToken(user, storedToken.getId());
        UserResponse userResponse = userMapper.toResponse(user);

        return AuthResponse.builder()
                .accessToken(newAccessToken)
                .refreshToken(request.getRefreshToken())
                .user(userResponse)
                .build();
    }

    @Override
    public void forgotPassword(ForgotPasswordRequest request) {

        // Không throw lỗi nếu email không tồn tại — bảo mật
        userRepository.lockAuthUserByEmail(request.getEmail()).ifPresent(user -> {
            refreshTokenRepository.revokeAllUserTokensByType(user, TokenType.RESET_PASSWORD);

            String resetToken = jwtService.generateResetPasswordToken(user);

            RefreshToken tokenEntity = RefreshToken.builder()
                    .user(user)
                    .token(resetToken)
                    .type(TokenType.RESET_PASSWORD)
                    .expiredAt(LocalDateTime.now().plusMinutes(15))
                    .lastUsedAt(LocalDateTime.now())
                    .revoked(false)
                    .build();

            refreshTokenRepository.save(tokenEntity);
            emailService.sendPasswordResetEmail(user.getEmail(), user.getFullName(), resetToken);
            log.info("Password reset email sent to: {}", user.getEmail());

            activityLogService.record(user.getId(), ActivityAction.PASSWORD_RESET_REQUESTED, "USER", user.getId(),
                    "Password reset requested", null, null);
        });
    }


    @Override
    public void resetPassword(ResetPasswordRequest request) {

        if (!request.getNewPassword().equals(request.getConfirmPassword())) {
            throw new AppException(ErrorCode.PASSWORD_MISMATCH);
        }

        User user = lockTokenUser(request.getToken(), TokenType.RESET_PASSWORD, ErrorCode.INVALID_RESET_TOKEN);
        RefreshToken resetToken = refreshTokenRepository
                .findByTokenAndTypeAndRevokedFalse(request.getToken(), TokenType.RESET_PASSWORD)
                .orElseThrow(() -> new AppException(ErrorCode.INVALID_RESET_TOKEN));

        if (resetToken.getExpiredAt().isBefore(LocalDateTime.now())) {
            resetToken.setRevoked(true);
            refreshTokenRepository.save(resetToken);
            throw new AppException(ErrorCode.INVALID_RESET_TOKEN);
        }


        if (passwordEncoder.matches(request.getNewPassword(), user.getPassword())) {
            throw new AppException(ErrorCode.NEW_PASSWORD_SAME_AS_OLD);
        }

        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        // Revoke tất cả token — bắt đăng nhập lại
        refreshTokenRepository.revokeAllUserTokens(user);

        afterCommit(() -> activityLogService.record(user.getId(), ActivityAction.PASSWORD_RESET_COMPLETED,
                "USER", user.getId(), "Password reset completed via token", null, null));

    }


    @Override
    public void changePassword(String email, ChangePasswordRequest request) {

        if (!request.getNewPassword().equals(request.getConfirmPassword())) {
            throw new AppException(ErrorCode.PASSWORD_MISMATCH);
        }

        User user = userRepository.lockAuthUserByEmail(email)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        if (!passwordEncoder.matches(request.getOldPassword(), user.getPassword())) {
            throw new AppException(ErrorCode.INVALID_OLD_PASSWORD);
        }

        if (passwordEncoder.matches(request.getNewPassword(), user.getPassword())) {
            throw new AppException(ErrorCode.NEW_PASSWORD_SAME_AS_OLD);
        }

        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        // Revoke tất cả token — bắt đăng nhập lại trên tất cả thiết bị
        refreshTokenRepository.revokeAllUserTokens(user);

        afterCommit(() -> activityLogService.record(user.getId(), ActivityAction.PASSWORD_CHANGE,
                "USER", user.getId(), "Password changed successfully", null, null));

    }


    private void afterCommit(Runnable audit) {
        // Audit uses REQUIRES_NEW. Run after releasing the updated user row so
        // its foreign-key check cannot wait on the enclosing password change.
        if (org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive()) {
            org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(
                    new org.springframework.transaction.support.TransactionSynchronization() {
                        @Override public void afterCommit() {
                            try { audit.run(); }
                            catch (RuntimeException error) { log.error("Authentication audit failed after commit", error); }
                        }
                    });
        } else audit.run();
    }

    private User lockTokenUser(String token, TokenType type, ErrorCode error) {
        java.util.UUID userId = refreshTokenRepository.findActiveTokenUserId(token, type)
                .orElseThrow(() -> new AppException(error));
        // Always lock user first, then re-read the token. A waiting refresh must
        // see revocation committed by logout / reset, never restore a stale row.
        return userRepository.lockAuthUserById(userId)
                .orElseThrow(() -> new AppException(error));
    }

    private AuthResponse buildAuthResponse(User user) {
        String refreshTokenValue = jwtService.generateRefreshToken(user);

        RefreshToken refreshToken = RefreshToken.builder()
                .user(user)
                .token(refreshTokenValue)
                .type(TokenType.REFRESH)
                .expiredAt(jwtService.extractExpiration(refreshTokenValue))
                .lastUsedAt(LocalDateTime.now())
                .revoked(false)
                .build();

        RefreshToken storedSession = refreshTokenRepository.save(refreshToken);
        String accessToken = jwtService.generateAccessToken(user, storedSession.getId());

        UserResponse userResponse = userMapper.toResponse(user);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshTokenValue)
                .user(userResponse)
                .build();
    }
}
