package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

import java.util.UUID;

@Data
public class AppointmentAssignmentRequest {
    @NotBlank
    @Pattern(regexp = "CHECK_IN|CHECK_OUT")
    private String scheduleType;

    // Null removes the current assignment.
    private UUID staffId;
}
