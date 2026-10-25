package com.storehub.integration;

import com.storehub.dto.request.*;
import com.storehub.dto.response.AuthResponse;
import com.storehub.exception.*;
import com.storehub.scheduler.RefundDispatcher;
import com.storehub.service.*;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ContextConfiguration(initializers = DisposableDatabaseGuard.class)
@EnabledIfEnvironmentVariable(named = "STOREHUB_INTEGRATION_TEST", matches = "true")
class AuthSessionDatabaseTest {
    @Autowired AuthService auth;
    @Autowired JdbcTemplate jdbc;
    @Autowired MockMvc mvc;
    @MockBean EmailService email;
    @MockBean RefundDispatcher refunds;
    private static final String PASSWORD = "OldPassword123!";

    @Test void changingPasswordRejectsOldAccessAndRefreshWhileNewLoginWorks() throws Exception {
        Account account = account();
        allowed(account.session().getAccessToken());
        ChangePasswordRequest change = new ChangePasswordRequest();
        change.setOldPassword(PASSWORD); change.setNewPassword("NewPassword123!"); change.setConfirmPassword("NewPassword123!");
        auth.changePassword(account.email(), change);
        rejected(account.session().getAccessToken());
        refreshRejected(account.session().getRefreshToken());
        assertEquals(ErrorCode.INVALID_CREDENTIALS, assertThrows(AppException.class,
                () -> login(account.email(), PASSWORD)).getErrorCode());
        allowed(login(account.email(), "NewPassword123!").getAccessToken());
    }

    @Test void resetRevokesEveryAccessTokenIssuedFromTheOldSession() throws Exception {
        Account account = account();
        AuthResponse refreshed = auth.refreshToken(new RefreshTokenRequest(account.session().getRefreshToken()));
        ForgotPasswordRequest forgot = new ForgotPasswordRequest(); forgot.setEmail(account.email()); auth.forgotPassword(forgot);
        String reset = jdbc.queryForObject("""
                SELECT rt.token FROM refresh_tokens rt JOIN users u ON u.id = rt.user_id
                WHERE u.email = ? AND rt.type = 'RESET_PASSWORD' AND NOT rt.revoked
                """, String.class, account.email());
        ResetPasswordRequest request = new ResetPasswordRequest(); request.setToken(reset);
        request.setNewPassword("ResetPassword123!"); request.setConfirmPassword("ResetPassword123!");
        auth.resetPassword(request);
        rejected(account.session().getAccessToken()); rejected(refreshed.getAccessToken());
        refreshRejected(account.session().getRefreshToken());
        assertEquals(ErrorCode.INVALID_RESET_TOKEN, assertThrows(AppException.class,
                () -> auth.resetPassword(request)).getErrorCode());
        allowed(login(account.email(), "ResetPassword123!").getAccessToken());
    }

    @Test void logoutInvalidatesAccessImmediatelyAndDoesNotAffectAnotherAccount() throws Exception {
        Account first = account(), other = account();
        allowed(first.session().getAccessToken());
        auth.logout(first.session().getRefreshToken());
        rejected(first.session().getAccessToken()); refreshRejected(first.session().getRefreshToken());
        allowed(other.session().getAccessToken());
    }

    @Test void aNewLoginRevokesAccessFromThePreviousLoginAndLegacyAccessNeedsRefresh() throws Exception {
        Account account = account();
        AuthResponse newLogin = login(account.email(), PASSWORD);
        rejected(account.session().getAccessToken()); allowed(newLogin.getAccessToken());
        String legacy = Jwts.builder().subject(account.email()).claim("type", "ACCESS")
                .expiration(new Date(System.currentTimeMillis() + 600000))
                .signWith(Keys.hmacShaKeyFor(System.getenv("JWT_SECRET").getBytes(StandardCharsets.UTF_8))).compact();
        rejected(legacy);
        allowed(auth.refreshToken(new RefreshTokenRequest(newLogin.getRefreshToken())).getAccessToken());
    }

    @Test void refreshRacingWithLogoutCannotReviveTheRevokedSession() throws Exception {
        Account account = account();
        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2), start = new CountDownLatch(1);
        try {
            Future<AuthResponse> refresh = pool.submit(() -> {
                ready.countDown(); assertTrue(start.await(10, TimeUnit.SECONDS));
                try { return auth.refreshToken(new RefreshTokenRequest(account.session().getRefreshToken())); }
                catch (AppException error) { assertEquals(ErrorCode.INVALID_REFRESH_TOKEN, error.getErrorCode()); return null; }
            });
            Future<?> logout = pool.submit(() -> {
                ready.countDown();
                try { assertTrue(start.await(10, TimeUnit.SECONDS)); }
                catch (InterruptedException ex) { throw new RuntimeException(ex); }
                auth.logout(account.session().getRefreshToken());
            });
            assertTrue(ready.await(10, TimeUnit.SECONDS)); start.countDown();
            AuthResponse raced = refresh.get(20, TimeUnit.SECONDS); logout.get(20, TimeUnit.SECONDS);
            rejected(account.session().getAccessToken());
            if (raced != null) rejected(raced.getAccessToken());
            refreshRejected(account.session().getRefreshToken());
            assertEquals(Boolean.TRUE, jdbc.queryForObject("SELECT revoked FROM refresh_tokens WHERE token = ?",
                    Boolean.class, account.session().getRefreshToken()));
        } finally { start.countDown(); pool.shutdownNow(); }
    }

    private Account account() {
        assertTrue(jdbc.queryForObject("SELECT current_database()", String.class).startsWith("storehub_it_"));
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        String email = "session-" + suffix + "@example.invalid";
        RegisterRequest register = new RegisterRequest(); register.setUsername("session-" + suffix);
        register.setEmail(email); register.setPassword(PASSWORD); register.setFullName("Session test"); register.setPhone("0912345678");
        auth.register(register);
        return new Account(email, login(email, PASSWORD));
    }

    private AuthResponse login(String email, String password) {
        LoginRequest request = new LoginRequest(); request.setEmail(email); request.setPassword(password);
        return auth.login(request);
    }
    private void allowed(String token) throws Exception {
        mvc.perform(get("/api/v1/customer/storage/my-units").header("Authorization", "Bearer " + token)).andExpect(status().isOk());
    }
    private void rejected(String token) throws Exception {
        mvc.perform(get("/api/v1/customer/storage/my-units").header("Authorization", "Bearer " + token)).andExpect(status().isUnauthorized());
    }
    private void refreshRejected(String token) {
        assertEquals(ErrorCode.INVALID_REFRESH_TOKEN, assertThrows(AppException.class,
                () -> auth.refreshToken(new RefreshTokenRequest(token))).getErrorCode());
    }
    private record Account(String email, AuthResponse session) {}
}
