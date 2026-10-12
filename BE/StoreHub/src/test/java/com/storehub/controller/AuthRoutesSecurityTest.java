package com.storehub.controller;

import com.storehub.config.JwtAuthenticationFilter;
import com.storehub.config.SecurityConfig;
import com.storehub.service.AuthService;
import com.storehub.service.BookingService;
import com.storehub.service.impl.JwtServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.mockito.Mockito.verify;

@WebMvcTest({AuthController.class, BookingController.class})
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class AuthRoutesSecurityTest {
    @Autowired MockMvc mvc;
    @MockBean AuthService authService;
    @MockBean BookingService bookingService;
    @MockBean JwtServiceImpl jwtService;
    @MockBean UserDetailsService userDetailsService;

    @Test
    void changePasswordRequiresAuthenticationWhileLoginAndRefreshRemainPublic() throws Exception {
        mvc.perform(put("/api/v1/auth/change-password")
                        .contentType("application/json")
                        .content("{\"oldPassword\":\"oldpass\",\"newPassword\":\"newpass\",\"confirmPassword\":\"newpass\"}"))
                .andExpect(status().isUnauthorized());

        mvc.perform(put("/api/v1/auth/change-password")
                        .with(user("owner@example.com").roles("CUSTOMER"))
                        .contentType("application/json")
                        .content("{\"oldPassword\":\"oldpass\",\"newPassword\":\"newpass\",\"confirmPassword\":\"newpass\"}"))
                .andExpect(status().isOk());

        mvc.perform(post("/api/v1/auth/login")
                        .contentType("application/json")
                        .content("{\"email\":\"owner@example.com\",\"password\":\"password\"}"))
                .andExpect(status().isOk());

        mvc.perform(post("/api/v1/auth/refresh-token")
                        .contentType("application/json")
                        .content("{\"refreshToken\":\"token\"}"))
                .andExpect(status().isOk());
    }

    @Test
    void pendingBookingsRequireCustomerIdentity() throws Exception {
        mvc.perform(get("/api/v1/bookings/my-pending"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/bookings/my-pending")
                        .with(user("staff@example.com").roles("FACILITY_STAFF")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/bookings/my-pending")
                        .with(user("owner@example.com").roles("CUSTOMER")))
                .andExpect(status().isOk());
        verify(bookingService).getPayableBookings("owner@example.com");
    }
}
