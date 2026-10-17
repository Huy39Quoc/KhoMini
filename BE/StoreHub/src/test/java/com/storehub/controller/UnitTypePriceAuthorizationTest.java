package com.storehub.controller;

import com.storehub.config.JwtAuthenticationFilter;
import com.storehub.config.SecurityConfig;
import com.storehub.service.UnitTypeManagementService;
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

import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(UnitTypeController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class})
class UnitTypePriceAuthorizationTest {
    @Autowired MockMvc mvc;
    @MockBean UnitTypeManagementService unitTypes;
    @MockBean JwtServiceImpl jwtService;
    @MockBean UserDetailsService userDetailsService;

    private final String path = "/api/v1/unit-types/" + UUID.randomUUID() + "/price";
    private static final String BODY = "{\"basePricePerMonth\":500000,\"depositAmount\":500000}";

    @Test
    void businessManagerRequiresTheUpdatePermission() throws Exception {
        mvc.perform(put(path).with(user("manager@example.com")
                        .authorities(new SimpleGrantedAuthority("ROLE_BUSINESS_MANAGER")))
                        .contentType("application/json").content(BODY))
                .andExpect(status().isForbidden());
        verifyNoInteractions(unitTypes);

        mvc.perform(put(path).with(user("manager@example.com")
                        .authorities(new SimpleGrantedAuthority("ROLE_BUSINESS_MANAGER"),
                                new SimpleGrantedAuthority("UNIT_TYPE_UPDATE")))
                        .contentType("application/json").content(BODY))
                .andExpect(status().isOk());
    }

    @Test
    void unrelatedRoleCannotGainPriceEditingWithPermissionAlone() throws Exception {
        mvc.perform(put(path).with(user("staff@example.com")
                        .authorities(new SimpleGrantedAuthority("ROLE_STAFF"),
                                new SimpleGrantedAuthority("UNIT_TYPE_UPDATE")))
                        .contentType("application/json").content(BODY))
                .andExpect(status().isForbidden());
        verifyNoInteractions(unitTypes);
    }

    @Test
    void adminCannotEditPricesBecausePricingBelongsToTheBusinessManager() throws Exception {
        mvc.perform(put(path).with(user("admin@example.com")
                        .authorities(new SimpleGrantedAuthority("ROLE_ADMIN"),
                                new SimpleGrantedAuthority("UNIT_TYPE_UPDATE")))
                        .contentType("application/json").content(BODY))
                .andExpect(status().isForbidden());
        verifyNoInteractions(unitTypes);
    }
}
