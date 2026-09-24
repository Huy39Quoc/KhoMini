package com.storehub.dto.response;

import java.util.UUID;

public record FacilityStaffResponse(
        UUID id,
        String fullName,
        String email,
        String role
) {}