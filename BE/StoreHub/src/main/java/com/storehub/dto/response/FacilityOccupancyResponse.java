package com.storehub.dto.response;

import lombok.*;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FacilityOccupancyResponse {
    private UUID facilityId;
    private String facilityName;
    private long totalUnits;
    private long occupiedUnits;
    private long availableUnits;
    private long reservedUnits;
    private long maintenanceUnits;
    private long overdue;
    private double occupancyRate; // percentage, 0-100
}
