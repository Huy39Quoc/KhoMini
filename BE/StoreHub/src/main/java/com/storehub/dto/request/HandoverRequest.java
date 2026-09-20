package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HandoverRequest {

    @NotBlank(message = "Unit condition is required")
    private String unitCondition;

    @NotBlank(message = "Lock condition is required")
    private String lockCondition;

    private String notes;
}