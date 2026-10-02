package com.storehub.controller;

import com.storehub.common.ApiResponse;
import com.storehub.dto.response.FacilityOccupancyResponse;
import com.storehub.dto.response.FacilityRevenueResponse;
import com.storehub.dto.response.OccupancyReportResponse;
import com.storehub.dto.response.RevenueReportResponse;
import com.storehub.dto.response.UnitTypeOccupancyResponse;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.service.ReportService;
import io.swagger.v3.oas.annotations.Operation;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.LocalDate;

@RestController
@RequestMapping("api/v1/reports")
@Tag(
        name = "Reports",
        description = "API tổng hợp báo cáo doanh thu và tỷ lệ lấp đầy kho toàn hệ thống"
)
@RequiredArgsConstructor
@Slf4j
public class ReportController {

    private final ReportService reportService;

    @GetMapping("/revenue")
    @PreAuthorize("hasAnyRole('ADMIN', 'BUSINESS_MANAGER')")
    @Operation(summary = "Lấy báo cáo doanh thu toàn hệ thống")
    public ResponseEntity<ApiResponse<RevenueReportResponse>> getRevenueReport(
            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
            LocalDate fromDate,

            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
            LocalDate toDate
    ) {
        RevenueReportResponse response =
                reportService.getRevenueReport(fromDate, toDate);

        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/export")
    @PreAuthorize("hasAnyRole('ADMIN', 'BUSINESS_MANAGER')")
    @Operation(summary = "Xuất báo cáo toàn hệ thống dạng CSV (type = revenue | occupancy)")
    public ResponseEntity<String> exportReport(
            @RequestParam String type,

            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
            LocalDate fromDate,

            @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
            LocalDate toDate
    ) {
        StringBuilder csv = new StringBuilder();

        if ("revenue".equalsIgnoreCase(type)) {
            RevenueReportResponse report =
                    reportService.getRevenueReport(fromDate, toDate);
            csv.append("facility,total_revenue,deposit,rental_fee,extra_charge,payments\n");
            for (FacilityRevenueResponse f : report.getByFacility()) {
                csv.append(csvCell(f.getFacilityName())).append(',')
                        .append(f.getTotalRevenue()).append(',')
                        .append(f.getDepositRevenue()).append(',')
                        .append(f.getRentalFeeRevenue()).append(',')
                        .append(f.getExtraChargeRevenue()).append(',')
                        .append(f.getPaymentCount()).append('\n');
            }
        } else if ("occupancy".equalsIgnoreCase(type)) {
            OccupancyReportResponse report = reportService.getOccupancyReport();
            csv.append("facility,total_units,occupied,available,reserved,maintenance,overdue_bookings,occupancy_rate\n");
            for (FacilityOccupancyResponse f : report.getByFacility()) {
                csv.append(csvCell(f.getFacilityName())).append(',')
                        .append(f.getTotalUnits()).append(',')
                        .append(f.getOccupiedUnits()).append(',')
                        .append(f.getAvailableUnits()).append(',')
                        .append(f.getReservedUnits()).append(',')
                        .append(f.getMaintenanceUnits()).append(',')
                        .append(f.getOverdueBookings()).append(',')
                        .append(f.getOccupancyRate()).append('\n');
            }
            csv.append('\n');
            csv.append("unit_type,total_units,occupied,available,reserved,maintenance,occupancy_rate\n");
            for (UnitTypeOccupancyResponse t : report.getByUnitType()) {
                csv.append(csvCell(t.getTypeName())).append(',')
                        .append(t.getTotalUnits()).append(',')
                        .append(t.getOccupiedUnits()).append(',')
                        .append(t.getAvailableUnits()).append(',')
                        .append(t.getReservedUnits()).append(',')
                        .append(t.getMaintenanceUnits()).append(',')
                        .append(t.getOccupancyRate()).append('\n');
            }
            csv.append('\n');
            csv.append("booking_status,count\n");
            report.getBookingsByStatus().forEach((status, count) ->
                    csv.append(status).append(',').append(count).append('\n'));
        } else {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        return ResponseEntity.ok()
                .header("Content-Type", "text/csv; charset=UTF-8")
                .header("Content-Disposition",
                        "attachment; filename=\"report-" + type.toLowerCase() + ".csv\"")
                .body(csv.toString());
    }

    private static String csvCell(String value) {
        if (value == null) {
            return "";
        }
        String escaped = value.replace("\"", "\"\"");
        return escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n")
                ? "\"" + escaped + "\""
                : escaped;
    }

    @GetMapping("/occupancy")
    @PreAuthorize("hasAnyRole('ADMIN', 'BUSINESS_MANAGER')")
    @Operation(summary = "Lấy báo cáo tỷ lệ lấp đầy kho")
    public ResponseEntity<ApiResponse<OccupancyReportResponse>> getOccupancyReport() {
        OccupancyReportResponse response = reportService.getOccupancyReport();

        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
