package com.storehub.service;

import com.storehub.dto.request.*;
import com.storehub.dto.response.AuthResponse;

public interface AuthService {
    AuthResponse register(RegisterRequest request);
    AuthResponse login(LoginRequest request);
    void logout(String refreshToken);
    AuthResponse refreshToken(RefreshTokenRequest request);
    void forgotPassword(ForgotPasswordRequest request);
    void resetPassword(ResetPasswordRequest request);
    void changePassword(String email, ChangePasswordRequest request);
}