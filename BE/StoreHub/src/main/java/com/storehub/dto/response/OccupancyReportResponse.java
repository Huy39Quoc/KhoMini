package com.storehub.dto.response;

import lombok.*;

import java.util.List;

@Data
@AllArgsConstructor
@Builder
public class OccupancyReportResponse {
    private SystemOccupancyResponse systemSummary;
    private List<FacilityOccupancyResponse> byFacility;
    private List<UnitTypeOccupancyResponse> byUnitType;
    private java.util.Map<String, Long> bookingsByStatus;
}
