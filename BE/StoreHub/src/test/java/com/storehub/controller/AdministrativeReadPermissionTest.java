package com.storehub.controller;

import com.storehub.config.JwtAuthenticationFilter;
import com.storehub.config.SecurityConfig;
import com.storehub.service.ActivityLogService;
import com.storehub.service.UserService;
import com.storehub.service.impl.JwtServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest({UserController.class, ActivityLogController.class})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class AdministrativeReadPermissionTest {
    @Autowired MockMvc mvc;
    @MockBean UserService userService;
    @MockBean ActivityLogService activityLogService;
    @MockBean JwtServiceImpl jwtService;
    @MockBean com.storehub.service.AccessSessionService accessSessions;
    @MockBean UserDetailsService userDetailsService;

    @Test
    void userReadEndpointsRequireUserViewPermission() throws Exception {
        mvc.perform(get("/api/v1/users/summary")
                        .with(user("admin@example.com").roles("ADMIN")))
                .andExpect(status().isForbidden());
        verifyNoInteractions(userService);

        mvc.perform(get("/api/v1/users/summary")
                        .with(user("admin@example.com").authorities(
                                new SimpleGrantedAuthority("ROLE_ADMIN"),
                                new SimpleGrantedAuthority("USER_VIEW"))))
                .andExpect(status().isOk());
    }

    @Test
    void loginHistoryPermissionIsIndependentFromActivityLogPermission() throws Exception {
        mvc.perform(get("/api/v1/activity-logs/login-history")
                        .with(user("admin@example.com").authorities(
                                new SimpleGrantedAuthority("ROLE_ADMIN"),
                                new SimpleGrantedAuthority("ACTIVITY_LOG_VIEW"))))
                .andExpect(status().isForbidden());

        mvc.perform(get("/api/v1/activity-logs/login-history")
                        .with(user("admin@example.com").authorities(
                                new SimpleGrantedAuthority("ROLE_ADMIN"),
                                new SimpleGrantedAuthority("LOGIN_HISTORY_VIEW"))))
                .andExpect(status().isOk());

        mvc.perform(get("/api/v1/activity-logs")
                        .with(user("admin@example.com").authorities(
                                new SimpleGrantedAuthority("ROLE_ADMIN"),
                                new SimpleGrantedAuthority("LOGIN_HISTORY_VIEW"))))
                .andExpect(status().isForbidden());
    }
}
