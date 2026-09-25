package com.storehub.dto.response;

import lombok.*;

@Data
@AllArgsConstructor
@Builder
public class FacilityOccupancyResponse {
    private Long facilityId;
    private String facilityName;
    private long totalUnits;
    private long occupiedUnits;
    private long availableUnits;
    private long reservedUnits;
    private long maintenanceUnits;
    private double occupancyRate; // percentage, 0-100
}
