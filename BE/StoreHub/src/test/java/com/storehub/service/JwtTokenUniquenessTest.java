package com.storehub.service;

import com.storehub.entity.User;
import com.storehub.enums.TokenType;
import com.storehub.service.impl.JwtServiceImpl;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class JwtTokenUniquenessTest {
    private static final String SECRET = "test-only-jwt-signing-key-at-least-32-bytes";

    private final JwtServiceImpl service = new JwtServiceImpl();
    private final User user = User.builder().email("customer@example.com").build();

    @BeforeEach
    void configureJwt() {
        ReflectionTestUtils.setField(service, "secretKey", SECRET);
        ReflectionTestUtils.setField(service, "refreshTokenExpiration", 7L * 24 * 60 * 60 * 1000);
    }

    @Test
    void repeatedLoginsCanPersistDistinctRefreshTokens() {
        assertDistinctSignedTokens(
                service.generateRefreshToken(user),
                service.generateRefreshToken(user),
                TokenType.REFRESH);
    }

    @Test
    void repeatedPasswordResetRequestsCanPersistDistinctTokens() {
        assertDistinctSignedTokens(
                service.generateResetPasswordToken(user),
                service.generateResetPasswordToken(user),
                TokenType.RESET_PASSWORD);
    }

    private void assertDistinctSignedTokens(String first, String second, TokenType type) {
        Claims firstClaims = parse(first);
        Claims secondClaims = parse(second);

        assertNotNull(firstClaims.getId());
        assertNotNull(secondClaims.getId());
        assertNotEquals(firstClaims.getId(), secondClaims.getId());
        assertNotEquals(first, second);
        assertEquals(user.getEmail(), firstClaims.getSubject());
        assertEquals(type.name(), firstClaims.get("type", String.class));
        assertTrue(service.isTokenValid(first));
        assertTrue(service.isTokenValid(second));
    }

    private Claims parse(String token) {
        return Jwts.parser()
                .verifyWith(Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8)))
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}
