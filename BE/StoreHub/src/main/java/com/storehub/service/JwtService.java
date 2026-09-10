package com.storehub.service;

import com.storehub.entity.User;

public interface JwtService {
    String generateAccessToken(User user);
    String generateRefreshToken(User user);
    String generateResetPasswordToken(User user);
    String extractEmail(String token);
    boolean isTokenValid(String token);
    boolean isTokenExpired(String token);

}
