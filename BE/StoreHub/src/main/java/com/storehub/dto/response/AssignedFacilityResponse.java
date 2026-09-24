package com.storehub.dto.response;

import java.util.UUID;

public record AssignedFacilityResponse(
        UUID id,
        String name,
        String address
) {}