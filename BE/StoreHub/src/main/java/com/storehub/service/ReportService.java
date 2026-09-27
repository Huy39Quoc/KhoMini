package com.storehub.service;

import com.storehub.dto.response.OccupancyReportResponse;
import com.storehub.dto.response.RevenueReportResponse;

import java.time.LocalDate;

public interface ReportService {
    RevenueReportResponse getRevenueReport(LocalDate fromDate, LocalDate toDate);
    OccupancyReportResponse getOccupancyReport();
}
