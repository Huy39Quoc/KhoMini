package com.storehub.dto.response;

import java.util.UUID;

public record FacilityReportResponse(
        UUID facilityId,
        long total,
        long available,
        long reserved,
        long occupied,
        long underMaintenance,
        double occupancyRate
) {}