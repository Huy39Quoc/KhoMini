package com.storehub.dto.response;

public record UserSummaryResponse(
        long totalUsers,
        long activeUsers
) {
}
