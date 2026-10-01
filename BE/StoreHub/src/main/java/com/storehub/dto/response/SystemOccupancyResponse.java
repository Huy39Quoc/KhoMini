package com.storehub.dto.response;

import lombok.*;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SystemOccupancyResponse {
    private long totalUnits;
    private long occupiedUnits;
    private long availableUnits;
    private long reservedUnits;
    private long maintenanceUnits;
    private long overdue;
    private double occupancyRate; // percentage, 0-100
}
