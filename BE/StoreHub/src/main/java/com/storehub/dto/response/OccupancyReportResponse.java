package com.storehub.dto.response;

import lombok.*;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OccupancyReportResponse {
    private SystemOccupancyResponse systemSummary;
    private List<FacilityOccupancyResponse> byFacility;
    private Long overdue;
}
