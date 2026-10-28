package com.storehub.service.impl;

import com.storehub.dto.response.*;
import com.storehub.entity.Facility;
import com.storehub.entity.UnitType;
import com.storehub.enums.UnitStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.enums.BookingStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.service.ReportService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true) // reports only read data, never mutate it
public class ReportServiceImpl implements ReportService {

    private static final LocalDateTime REPORT_RANGE_START =
            LocalDate.of(1970, 1, 1).atStartOfDay();
    private static final LocalDateTime REPORT_RANGE_END =
            LocalDate.of(9999, 12, 31).atTime(LocalTime.MAX);

    private final PaymentRepository paymentRepository;
    private final RefundRequestRepository refundRequestRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final BookingRepository bookingRepository;
    private final FacilityRepository facilityRepository;
    private final UnitTypeRepository unitTypeRepository;
    private final com.storehub.repository.DepositDeductionRepository depositDeductions;

    @Override
    @Transactional(readOnly = true, isolation = org.springframework.transaction.annotation.Isolation.REPEATABLE_READ)
    public RevenueReportResponse getRevenueReport(LocalDate fromDate, LocalDate toDate) {
        if (fromDate != null && toDate != null && fromDate.isAfter(toDate)) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        LocalDateTime from = fromDate != null ? fromDate.atStartOfDay() : REPORT_RANGE_START;
        LocalDateTime to = toDate != null ? toDate.atTime(LocalTime.MAX) : REPORT_RANGE_END;

        List<FacilityRevenueResponse> captured = paymentRepository.sumRevenueByFacility(from, to);
        List<FacilityRevenueResponse> refunded = refundRequestRepository.sumCompletedRefundsByFacility(from, to);
        SystemRevenueSummaryResponse systemSummary = paymentRepository.sumSystemRevenue(from, to);
        SystemRevenueSummaryResponse systemRefunds = refundRequestRepository.sumCompletedRefundsSystem(from, to);
        BigDecimal overdueRevenue = paymentRepository.sumOverdueRevenue(from, to);
        BigDecimal overdueRefunds = refundRequestRepository.sumCompletedOverdueRefunds(from, to);
        if (systemSummary == null) {
            systemSummary = SystemRevenueSummaryResponse.builder()
                    .totalRevenue(BigDecimal.ZERO)
                    .depositRevenue(BigDecimal.ZERO)
                    .rentalFeeRevenue(BigDecimal.ZERO)
                    .extraChargeRevenue(BigDecimal.ZERO)
                    .paymentCount(0L)
                    .build();
        }

        if (systemRefunds != null) {
            systemSummary.setTotalRevenue(value(systemSummary.getTotalRevenue()).subtract(value(systemRefunds.getTotalRevenue())));
            systemSummary.setDepositRevenue(value(systemSummary.getDepositRevenue()).subtract(value(systemRefunds.getDepositRevenue())));
            systemSummary.setRentalFeeRevenue(value(systemSummary.getRentalFeeRevenue()).subtract(value(systemRefunds.getRentalFeeRevenue())));
            systemSummary.setExtraChargeRevenue(value(systemSummary.getExtraChargeRevenue()).subtract(value(systemRefunds.getExtraChargeRevenue())));
        }

        Map<UUID, FacilityRevenueResponse> facilityTotals = new LinkedHashMap<>();
        for (Facility f : facilityRepository.findAllByOrderByCreatedAtAsc()) {
            facilityTotals.put(f.getId(), FacilityRevenueResponse.builder()
                    .facilityId(f.getId())
                    .facilityName(f.getName())
                    .totalRevenue(BigDecimal.ZERO)
                    .depositRevenue(BigDecimal.ZERO)
                    .rentalFeeRevenue(BigDecimal.ZERO)
                    .extraChargeRevenue(BigDecimal.ZERO)
                    .paymentCount(0L)
                    .build());
        }
        for (FacilityRevenueResponse charge : captured) {
            facilityTotals.put(charge.getFacilityId(), charge);
        }
        for (FacilityRevenueResponse refund : refunded) {
            FacilityRevenueResponse total = facilityTotals.computeIfAbsent(refund.getFacilityId(), id ->
                    FacilityRevenueResponse.builder().facilityId(id).facilityName(refund.getFacilityName())
                            .totalRevenue(BigDecimal.ZERO).depositRevenue(BigDecimal.ZERO)
                            .rentalFeeRevenue(BigDecimal.ZERO).extraChargeRevenue(BigDecimal.ZERO)
                            .paymentCount(0L).build());
            total.setTotalRevenue(value(total.getTotalRevenue()).subtract(value(refund.getTotalRevenue())));
            total.setDepositRevenue(value(total.getDepositRevenue()).subtract(value(refund.getDepositRevenue())));
            total.setRentalFeeRevenue(value(total.getRentalFeeRevenue()).subtract(value(refund.getRentalFeeRevenue())));
            total.setExtraChargeRevenue(value(total.getExtraChargeRevenue()).subtract(value(refund.getExtraChargeRevenue())));
        }
        DepositReconciliationResponse systemDeposits = new DepositReconciliationResponse();
        for (var row : depositDeductions.reconcile(from, to)) {
            DepositReconciliationResponse deposits = new DepositReconciliationResponse(
                    value(row.getOpeningBalance()), value(row.getReceived()), value(row.getRefunded()),
                    value(row.getRetained()), value(row.getDamageRetained()), value(row.getCancellationRetained()));
            FacilityRevenueResponse facility = facilityTotals.computeIfAbsent(row.getFacilityId(), id ->
                    FacilityRevenueResponse.builder().facilityId(id).facilityName(row.getFacilityName())
                            .totalRevenue(BigDecimal.ZERO).depositRevenue(BigDecimal.ZERO)
                            .rentalFeeRevenue(BigDecimal.ZERO).extraChargeRevenue(BigDecimal.ZERO).paymentCount(0L).build());
            facility.setDepositReconciliation(deposits);
            facility.setDepositRetentionRevenue(deposits.getRetained());
            facility.setTotalRevenue(value(facility.getTotalRevenue()).add(deposits.getRetained()));
            systemDeposits.add(deposits);
        }
        systemSummary.setDepositReconciliation(systemDeposits);
        systemSummary.setDepositRetentionRevenue(systemDeposits.getRetained());
        systemSummary.setTotalRevenue(value(systemSummary.getTotalRevenue()).add(systemDeposits.getRetained()));
        List<FacilityRevenueResponse> byFacility = facilityTotals.values().stream()
                .sorted(Comparator.comparing(FacilityRevenueResponse::getFacilityName))
                .toList();

        return RevenueReportResponse.builder()
                .fromDate(fromDate)
                .toDate(toDate)
                .systemSummary(systemSummary)
                .byFacility(byFacility)
                .overdue(value(overdueRevenue).subtract(value(overdueRefunds)))
                .build();
    }

    private static BigDecimal value(BigDecimal amount) {
        return amount == null ? BigDecimal.ZERO : amount;
    }

    @Override
    public OccupancyReportResponse getOccupancyReport() {
        Map<UUID, String> facilityNames = new LinkedHashMap<>();
        // bucket layout per facility: [total, occupied, available, reserved, maintenance]
        Map<UUID, long[]> counts = new LinkedHashMap<>();

        for (Facility f : facilityRepository.findAllByOrderByCreatedAtAsc()) {
            facilityNames.put(f.getId(), f.getName());
            counts.put(f.getId(), new long[5]);
        }

        List<Object[]> rows = storageUnitRepository.countUnitsGroupedByFacilityAndStatus();

        for (Object[] row : rows) {
            UUID facilityId = (UUID) row[0];
            String facilityName = (String) row[1];
            
            UnitStatus status;
            if (row[2] instanceof UnitStatus us) {
                status = us;
            } else if (row[2] instanceof String str) {
                status = UnitStatus.valueOf(str);
            } else {
                continue;
            }
            Long count = row[3] instanceof Number num ? num.longValue() : 0L;

            facilityNames.putIfAbsent(facilityId, facilityName);
            long[] bucket = counts.computeIfAbsent(facilityId, k -> new long[5]);
            bucket[0] += count;
            switch (status) {
                case OCCUPIED -> bucket[1] += count;
                case AVAILABLE -> bucket[2] += count;
                case RESERVED -> bucket[3] += count;
                case UNDER_MAINTENANCE -> bucket[4] += count;
            }
        }

        Map<UUID, Long> overdueByFacility = new HashMap<>();
        for (Object[] row : bookingRepository.countOverdueGroupedByFacility()) {
            overdueByFacility.put(
                    (UUID) row[0],
                    row[1] instanceof Number num ? num.longValue() : 0L
            );
        }

        List<FacilityOccupancyResponse> byFacility = new ArrayList<>();
        long sysTotal = 0, sysOccupied = 0, sysAvailable = 0, sysReserved = 0, sysMaintenance = 0;
        long sysOverdue = 0;

        for (Map.Entry<UUID, long[]> entry : counts.entrySet()) {
            long[] c = entry.getValue();
            double rate = c[0] == 0 ? 0.0 : (c[1] * 100.0) / c[0];

            byFacility.add(FacilityOccupancyResponse.builder()
                    .facilityId(entry.getKey())
                    .facilityName(facilityNames.get(entry.getKey()))
                    .totalUnits(c[0])
                    .occupiedUnits(c[1])
                    .availableUnits(c[2])
                    .reservedUnits(c[3])
                    .maintenanceUnits(c[4])
                    .overdueBookings(overdueByFacility.getOrDefault(entry.getKey(), 0L))
                    .occupancyRate(round2(rate))
                    .build());

            sysOverdue += overdueByFacility.getOrDefault(entry.getKey(), 0L);

            sysTotal += c[0];
            sysOccupied += c[1];
            sysAvailable += c[2];
            sysReserved += c[3];
            sysMaintenance += c[4];
        }

        double systemRate = sysTotal == 0 ? 0.0 : (sysOccupied * 100.0) / sysTotal;

        SystemOccupancyResponse systemSummary = SystemOccupancyResponse.builder()
                .totalUnits(sysTotal)
                .occupiedUnits(sysOccupied)
                .availableUnits(sysAvailable)
                .reservedUnits(sysReserved)
                .maintenanceUnits(sysMaintenance)
                .overdueBookings(sysOverdue)
                .occupancyRate(round2(systemRate))
                .build();

        return OccupancyReportResponse.builder()
                .systemSummary(systemSummary)
                .byFacility(byFacility)
                .byUnitType(buildUnitTypeBreakdown())
                .bookingsByStatus(buildBookingStatusBreakdown())
                .build();
    }

    private List<UnitTypeOccupancyResponse> buildUnitTypeBreakdown() {
        Map<UUID, String> names = new LinkedHashMap<>();
        // bucket layout: [total, occupied, available, reserved, maintenance]
        Map<UUID, long[]> counts = new LinkedHashMap<>();

        for (UnitType ut : unitTypeRepository.findAll()) {
            names.put(ut.getId(), ut.getTypeName());
            counts.put(ut.getId(), new long[5]);
        }

        for (Object[] row : storageUnitRepository.countUnitsGroupedByUnitTypeAndStatus()) {
            UUID unitTypeId = (UUID) row[0];
            String typeName = (String) row[1];

            UnitStatus status;
            if (row[2] instanceof UnitStatus us) {
                status = us;
            } else if (row[2] instanceof String str) {
                status = UnitStatus.valueOf(str);
            } else {
                continue;
            }
            long count = row[3] instanceof Number num ? num.longValue() : 0L;

            names.putIfAbsent(unitTypeId, typeName);
            long[] bucket = counts.computeIfAbsent(unitTypeId, k -> new long[5]);
            bucket[0] += count;
            switch (status) {
                case OCCUPIED -> bucket[1] += count;
                case AVAILABLE -> bucket[2] += count;
                case RESERVED -> bucket[3] += count;
                case UNDER_MAINTENANCE -> bucket[4] += count;
            }
        }

        List<UnitTypeOccupancyResponse> result = new ArrayList<>();
        for (Map.Entry<UUID, long[]> entry : counts.entrySet()) {
            long[] c = entry.getValue();
            double rate = c[0] == 0 ? 0.0 : (c[1] * 100.0) / c[0];
            result.add(UnitTypeOccupancyResponse.builder()
                    .unitTypeId(entry.getKey())
                    .typeName(names.get(entry.getKey()))
                    .totalUnits(c[0])
                    .occupiedUnits(c[1])
                    .availableUnits(c[2])
                    .reservedUnits(c[3])
                    .maintenanceUnits(c[4])
                    .occupancyRate(round2(rate))
                    .build());
        }
        return result;
    }

    private Map<String, Long> buildBookingStatusBreakdown() {
        Map<String, Long> result = new LinkedHashMap<>();
        for (BookingStatus status : BookingStatus.values()) {
            result.put(status.name(), 0L);
        }
        for (Object[] row : bookingRepository.countGroupedByStatus()) {
            String key = row[0] == null ? null : row[0].toString();
            if (key != null) {
                result.put(key, row[1] instanceof Number num ? num.longValue() : 0L);
            }
        }
        return result;
    }

    private double round2(double value) {
        return Math.round(value * 100.0) / 100.0;
    }
}
