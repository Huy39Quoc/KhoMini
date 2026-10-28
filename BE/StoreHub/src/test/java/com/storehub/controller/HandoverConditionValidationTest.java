package com.storehub.controller;

import com.storehub.exception.GlobalExceptionHandler;
import com.storehub.service.FacilityOperationsService;
import com.storehub.service.GatePassService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import java.util.UUID;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class HandoverConditionValidationTest {
    FacilityOperationsService operations;
    MockMvc mvc;

    @BeforeEach
    void setup() {
        operations = mock(FacilityOperationsService.class);
        mvc = MockMvcBuilders.standaloneSetup(new FacilityOperationsController(operations, mock(GatePassService.class)))
                .setCustomArgumentResolvers(new org.springframework.security.web.method.annotation.AuthenticationPrincipalArgumentResolver())
                .setControllerAdvice(new GlobalExceptionHandler()).build();
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "{\"unitCondition\":\"BROKEN\",\"lockCondition\":\"LOCKED_WORKING\"}",
            "{\"unitCondition\":\"ABC\",\"lockCondition\":\"LOCKED_WORKING\"}",
            "{\"unitCondition\":\"không hư hỏng\",\"lockCondition\":\"LOCKED_WORKING\"}",
            "{\"unitCondition\":\"Đã vệ sinh sạch sẽ\",\"lockCondition\":\"LOCKED_WORKING\"}",
            "{\"unitCondition\":\"GOOD\",\"lockCondition\":\"ABC\"}",
            "{\"unitCondition\":\"\",\"lockCondition\":\"LOCKED_WORKING\"}",
            "{\"unitCondition\":0,\"lockCondition\":\"LOCKED_WORKING\"}",
            "{\"unitCondition\":\"GOOD\",\"lockCondition\":1}",
            "{\"unitCondition\":null,\"lockCondition\":\"LOCKED_WORKING\"}",
            "{\"unitCondition\":\"GOOD\"}",
            "{}"
    })
    void invalidConditionsReturn400BeforeAnyBusinessMutation(String body) throws Exception {
        for (String action : new String[]{"check-in", "check-out"}) {
            mvc.perform(post("/api/v1/facility/operations/" + UUID.randomUUID() + "/" + action)
                    .param("facilityId", UUID.randomUUID().toString())
                    .contentType(MediaType.APPLICATION_JSON).content(body))
                    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.status").value(400));
        }
        verifyNoInteractions(operations);
    }
}
