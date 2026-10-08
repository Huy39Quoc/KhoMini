package com.storehub.service;

import com.storehub.dto.response.FacilityOccupancyResponse;
import com.storehub.dto.response.OccupancyReportResponse;
import com.storehub.dto.response.RevenueReportResponse;
import com.storehub.dto.response.SystemRevenueSummaryResponse;
import com.storehub.enums.UnitStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.service.impl.ReportServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ReportServiceOverdueTest {

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private StorageUnitRepository storageUnitRepository;

    @Mock
    private BookingRepository bookingRepository;

    @InjectMocks
    private ReportServiceImpl reportService;

    @Test
    void testGetOccupancyReport_IncludesOverdueUnits() {
        UUID f1 = UUID.randomUUID();
        UUID f2 = UUID.randomUUID();

        // Row format: [facilityId, facilityName, unitStatus, count]
        List<Object[]> unitRows = new ArrayList<>();
        unitRows.add(new Object[]{f1, "Facility 1", UnitStatus.OCCUPIED, 10L});
        unitRows.add(new Object[]{f1, "Facility 1", UnitStatus.AVAILABLE, 5L});
        unitRows.add(new Object[]{f2, "Facility 2", UnitStatus.OCCUPIED, 8L});
        unitRows.add(new Object[]{f2, "Facility 2", UnitStatus.AVAILABLE, 2L});

        when(storageUnitRepository.countUnitsGroupedByFacilityAndStatus()).thenReturn(unitRows);

        // Overdue rows format: [facilityId, count]
        List<Object[]> overdueRows = new ArrayList<>();
        overdueRows.add(new Object[]{f1, 3L}); // 3 overdue in f1
        overdueRows.add(new Object[]{f2, 1L}); // 1 overdue in f2

        when(bookingRepository.countOverdueGroupedByFacility())
                .thenReturn(overdueRows);

        OccupancyReportResponse response = reportService.getOccupancyReport();

        assertNotNull(response);
        // Total overdue in system = 3 + 1 = 4
        assertEquals(4L, response.getSystemSummary().getOverdueBookings());

        assertEquals(2, response.getByFacility().size());

        FacilityOccupancyResponse f1Resp = response.getByFacility().stream()
                .filter(f -> f.getFacilityId().equals(f1))
                .findFirst().orElseThrow();
        assertEquals(3L, f1Resp.getOverdueBookings());

        FacilityOccupancyResponse f2Resp = response.getByFacility().stream()
                .filter(f -> f.getFacilityId().equals(f2))
                .findFirst().orElseThrow();
        assertEquals(1L, f2Resp.getOverdueBookings());
    }

    @Test
    void testGetRevenueReport_IncludesOverdueRevenue() {
        when(paymentRepository.sumRevenueByFacility(any(), any())).thenReturn(List.of());
        when(paymentRepository.sumSystemRevenue(any(), any())).thenReturn(
                SystemRevenueSummaryResponse.builder()
                        .totalRevenue(BigDecimal.valueOf(1000000))
                        .depositRevenue(BigDecimal.valueOf(500000))
                        .rentalFeeRevenue(BigDecimal.valueOf(400000))
                        .extraChargeRevenue(BigDecimal.valueOf(100000))
                        .paymentCount(5L)
                        .build()
        );
        when(paymentRepository.sumOverdueRevenue(any(), any())).thenReturn(BigDecimal.valueOf(50000));

        RevenueReportResponse response = reportService.getRevenueReport(null, null);

        assertNotNull(response);
        assertEquals(BigDecimal.valueOf(50000), response.getOverdue());
    }
}
