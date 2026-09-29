package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record FacilityUnitRequest(
        @NotBlank @Size(max = 30) String unitCode,
        @Size(max = 50) String floorLevel,
        @NotNull UUID unitTypeId
) {}