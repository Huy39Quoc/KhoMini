package com.storehub.dto.response;

import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RevenueReportResponse {
    private LocalDate fromDate;
    private LocalDate toDate;
    private SystemRevenueSummaryResponse systemSummary;
    private List<FacilityRevenueResponse> byFacility;
    private BigDecimal overdue;
}
