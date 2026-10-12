package com.storehub.dto.response;

import java.util.UUID;

public record AssignableStaffResponse(
        UUID id,
        String username,
        String fullName,
        String email,
        boolean isActive,
        String roleName
) {}
