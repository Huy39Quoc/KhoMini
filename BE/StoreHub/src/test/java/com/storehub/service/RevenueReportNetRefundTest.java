package com.storehub.service;

import com.storehub.dto.response.FacilityRevenueResponse;
import com.storehub.dto.response.RevenueReportResponse;
import com.storehub.dto.response.SystemRevenueSummaryResponse;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.service.impl.ReportServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RevenueReportNetRefundTest {
    @Mock PaymentRepository charges;
    @Mock RefundRequestRepository refunds;
    @Mock StorageUnitRepository units;
    @Mock BookingRepository bookings;
    @InjectMocks ReportServiceImpl report;

    @Test
    void refundInFebruaryDoesNotRewriteJanuaryRevenue() {
        UUID facilityId = UUID.randomUUID();
        var januaryCharge = facility(facilityId, "800", "200", "800", 2);
        var februaryRefund = facility(facilityId, "300", "100", "300", 0);
        when(charges.sumRevenueByFacility(any(), any())).thenAnswer(call ->
                call.getArgument(0, java.time.LocalDateTime.class).getMonthValue() == 1
                        ? List.of(januaryCharge) : List.of());
        when(refunds.sumCompletedRefundsByFacility(any(), any())).thenAnswer(call ->
                call.getArgument(0, java.time.LocalDateTime.class).getMonthValue() == 2
                        ? List.of(februaryRefund) : List.of());
        when(charges.sumSystemRevenue(any(), any())).thenAnswer(call ->
                call.getArgument(0, java.time.LocalDateTime.class).getMonthValue() == 1
                        ? summary("800", "200", "800", 2)
                        : summary("0", "0", "0", 0));
        when(refunds.sumCompletedRefundsSystem(any(), any())).thenAnswer(call ->
                call.getArgument(0, java.time.LocalDateTime.class).getMonthValue() == 2
                        ? summary("300", "100", "300", 0)
                        : summary("0", "0", "0", 0));
        when(charges.sumOverdueRevenue(any(), any())).thenReturn(BigDecimal.ZERO);
        when(refunds.sumCompletedOverdueRefunds(any(), any())).thenReturn(BigDecimal.ZERO);

        RevenueReportResponse january = report.getRevenueReport(
                LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 31));
        RevenueReportResponse february = report.getRevenueReport(
                LocalDate.of(2026, 2, 1), LocalDate.of(2026, 2, 28));

        assertEquals(new BigDecimal("800"), january.getSystemSummary().getTotalRevenue());
        assertEquals(new BigDecimal("200"), january.getSystemSummary().getDepositRevenue());
        assertEquals(2L, january.getSystemSummary().getPaymentCount());
        assertEquals(new BigDecimal("-300"), february.getSystemSummary().getTotalRevenue());
        assertEquals(new BigDecimal("-100"), february.getSystemSummary().getDepositRevenue());
        assertEquals(new BigDecimal("-300"), february.getByFacility().get(0).getTotalRevenue());
        assertEquals(0L, february.getByFacility().get(0).getPaymentCount());
    }

    private FacilityRevenueResponse facility(UUID id, String net, String deposit,
                                              String rental, long count) {
        return FacilityRevenueResponse.builder().facilityId(id).facilityName("Test facility")
                .totalRevenue(new BigDecimal(net)).depositRevenue(new BigDecimal(deposit))
                .rentalFeeRevenue(new BigDecimal(rental)).extraChargeRevenue(BigDecimal.ZERO)
                .paymentCount(count).build();
    }

    private SystemRevenueSummaryResponse summary(String net, String deposit,
                                                 String rental, long count) {
        return SystemRevenueSummaryResponse.builder()
                .totalRevenue(new BigDecimal(net)).depositRevenue(new BigDecimal(deposit))
                .rentalFeeRevenue(new BigDecimal(rental)).extraChargeRevenue(BigDecimal.ZERO)
                .paymentCount(count).build();
    }
}
