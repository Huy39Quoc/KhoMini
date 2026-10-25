package com.storehub.controller;

import com.storehub.config.JwtAuthenticationFilter;
import com.storehub.config.SecurityConfig;
import com.storehub.service.FacilityManagementService;
import com.storehub.service.impl.JwtServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.mockito.Mockito.verifyNoInteractions;

@WebMvcTest(FacilityManagementController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class FacilityManagementPermissionTest {
    @Autowired MockMvc mvc;
    @MockBean FacilityManagementService facilityManagementService;
    @MockBean com.storehub.service.HandoverIssueService handoverIssues;
    @MockBean JwtServiceImpl jwtService;
    @MockBean com.storehub.service.AccessSessionService accessSessions;
    @MockBean UserDetailsService userDetailsService;

    @Test
    void staffCannotResolveFacilityIssuesEvenWithBookingUpdatePermission() throws Exception {
        mvc.perform(post("/api/v1/facility/management/{facilityId}/bookings/{bookingId}/handover-issue", UUID.randomUUID(), UUID.randomUUID())
                        .with(user("staff@test.com").authorities(new SimpleGrantedAuthority("ROLE_STAFF"),
                                new SimpleGrantedAuthority("BOOKING_UPDATE")))
                        .contentType("application/json")
                        .content("{\"action\":\"CANCEL_REFUND\",\"notes\":\"Không cung cấp được dịch vụ\"}"))
                .andExpect(status().isForbidden());
        verifyNoInteractions(handoverIssues);
    }

    @Test
    void facilityManagerNeedsStorageUnitCreatePermission() throws Exception {
        UUID facilityId = UUID.randomUUID();
        String body = "{\"unitCode\":\"A-01\",\"unitTypeId\":\"" + UUID.randomUUID() + "\"}";
        mvc.perform(post("/api/v1/facility/management/{facilityId}/units", facilityId)
                        .with(user("manager@example.com").roles("FACILITY_MANAGER"))
                        .contentType("application/json")
                        .content(body))
                .andExpect(status().isForbidden());
        verifyNoInteractions(facilityManagementService);
    }

    @Test
    void storageUnitCreatePermissionAllowsRequest() throws Exception {
        UUID facilityId = UUID.randomUUID();
        String body = "{\"unitCode\":\"A-01\",\"unitTypeId\":\"" + UUID.randomUUID() + "\"}";
        mvc.perform(post("/api/v1/facility/management/{facilityId}/units", facilityId)
                        .with(user("manager@example.com").authorities(
                                new SimpleGrantedAuthority("ROLE_FACILITY_MANAGER"),
                                new SimpleGrantedAuthority("STORAGE_UNIT_CREATE")))
                        .contentType("application/json")
                        .content(body))
                .andExpect(status().isOk());
    }
}
