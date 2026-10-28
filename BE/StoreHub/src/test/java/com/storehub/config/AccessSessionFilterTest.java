package com.storehub.config;

import com.storehub.entity.User;
import com.storehub.enums.TokenType;
import com.storehub.repository.RefreshTokenRepository;
import com.storehub.service.AccessSessionService;
import com.storehub.service.impl.JwtServiceImpl;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.*;
import org.springframework.mock.web.*;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.util.ReflectionTestUtils;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AccessSessionFilterTest {
    private static final String SECRET = "session-test-secret-at-least-thirty-two-bytes";
    private final JwtServiceImpl jwt = new JwtServiceImpl();
    private final RefreshTokenRepository tokens = mock(RefreshTokenRepository.class);
    private final UserDetailsService users = mock(UserDetailsService.class);
    private final User user = User.builder().email("customer@test.com").build();
    private final UUID session = UUID.randomUUID();
    private final JwtAuthenticationFilter filter = new JwtAuthenticationFilter(jwt, users, new AccessSessionService(jwt, tokens));

    @BeforeEach void setup() {
        ReflectionTestUtils.setField(jwt, "secretKey", SECRET);
        ReflectionTestUtils.setField(jwt, "accessTokenExpiration", 900000L);
        user.setId(UUID.randomUUID());
    }
    @AfterEach void cleanup() { SecurityContextHolder.clearContext(); }

    @Test void signedAccessTokenAuthenticatesOnlyWithALiveSessionOwnedByItsSubject() throws Exception {
        String token = jwt.generateAccessToken(user, session);
        when(tokens.existsByIdAndUser_EmailAndTypeAndRevokedFalseAndExpiredAtAfter(
                eq(session), eq(user.getEmail()), eq(TokenType.REFRESH), any(LocalDateTime.class))).thenReturn(true);
        when(users.loadUserByUsername(user.getEmail())).thenReturn(
                org.springframework.security.core.userdetails.User.withUsername(user.getEmail()).password("hash").roles("CUSTOMER").build());
        request(token);
        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals(session, jwt.extractSessionId(token));
    }

    @Test void validSignatureAndFutureExpiryCannotAuthenticateARevokedOrMissingSession() throws Exception {
        String token = jwt.generateAccessToken(user, session);
        assertTrue(jwt.isAccessToken(token));
        request(token);
        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verifyNoInteractions(users);
        verify(tokens).existsByIdAndUser_EmailAndTypeAndRevokedFalseAndExpiredAtAfter(
                eq(session), eq(user.getEmail()), eq(TokenType.REFRESH), any(LocalDateTime.class));
    }

    @Test void oldAccessTokenWithoutASessionCannotBypassRevocation() throws Exception {
        String legacy = Jwts.builder().subject(user.getEmail()).claim("type", "ACCESS")
                .expiration(new Date(System.currentTimeMillis() + 900000))
                .signWith(Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8))).compact();
        request(legacy);
        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verifyNoInteractions(tokens, users);
    }

    @Test void accessTokenGenerationCannotAccidentallyOmitTheSession() {
        assertThrows(IllegalArgumentException.class, () -> jwt.generateAccessToken(user, null));
    }

    private void request(String token) throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/customer/storage/my-units");
        request.setServletPath("/api/v1/customer/storage/my-units");
        request.addHeader("Authorization", "Bearer " + token);
        filter.doFilter(request, new MockHttpServletResponse(), (req, response) -> {});
    }
}
