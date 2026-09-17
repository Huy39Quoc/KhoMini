package com.storehub.controller;

import com.storehub.common.response.ApiResponse;
import com.storehub.dto.response.OccupancyReportResponse;
import com.storehub.dto.response.RevenueReportResponse;
import com.storehub.service.ReportService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("api/v1/reports")
@RequiredArgsConstructor
@Slf4j
public class ReportController {
    private final ReportService reportService;

    @GetMapping("/revenue")
    public ResponseEntity<ApiResponse<RevenueReportResponse>> getRevenueReport(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate fromDate,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate toDate
    ) {
        log.info("Generating system-wide revenue report from {} to {}", fromDate, toDate);
        RevenueReportResponse response = reportService.getRevenueReport(fromDate, toDate);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/occupancy")
    public ResponseEntity<ApiResponse<OccupancyReportResponse>> getOccupancyReport() {
        log.info("Generating system-wide storage occupancy report");
        OccupancyReportResponse response = reportService.getOccupancyReport();
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
