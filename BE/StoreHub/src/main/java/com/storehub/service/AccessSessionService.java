package com.storehub.service;

import com.storehub.enums.TokenType;
import com.storehub.repository.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AccessSessionService {
    private final JwtService jwt;
    private final RefreshTokenRepository tokens;

    public boolean isActive(String token, String email) {
        UUID sessionId = jwt.extractSessionId(token);
        // Older access tokens without a session must refresh or log in again.
        return sessionId != null && tokens.existsByIdAndUser_EmailAndTypeAndRevokedFalseAndExpiredAtAfter(
                sessionId, email, TokenType.REFRESH, LocalDateTime.now());
    }
}
