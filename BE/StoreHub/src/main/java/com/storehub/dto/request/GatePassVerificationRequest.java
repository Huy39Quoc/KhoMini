package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class GatePassVerificationRequest {
    @NotBlank
    @Size(max = 100)
    private String token;
}
