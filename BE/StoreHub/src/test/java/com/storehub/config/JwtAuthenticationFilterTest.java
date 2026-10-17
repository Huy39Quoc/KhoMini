package com.storehub.config;

import com.storehub.service.impl.JwtServiceImpl;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetailsService;

import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class JwtAuthenticationFilterTest {

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void refreshTokenCannotAuthenticateProtectedRequest() throws Exception {
        JwtServiceImpl jwtService = mock(JwtServiceImpl.class);
        UserDetailsService userDetailsService = mock(UserDetailsService.class);
        JwtAuthenticationFilter filter = new JwtAuthenticationFilter(jwtService, userDetailsService);

        MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/v1/users");
        request.setServletPath("/api/v1/users");
        request.addHeader("Authorization", "Bearer refresh-token");

        when(jwtService.extractEmail("refresh-token")).thenReturn("staff@example.com");
        when(jwtService.isAccessToken("refresh-token")).thenReturn(false);

        filter.doFilter(request, new MockHttpServletResponse(), (req, res) ->
                assertNull(SecurityContextHolder.getContext().getAuthentication()));

        verify(userDetailsService, never()).loadUserByUsername("staff@example.com");
    }
}
