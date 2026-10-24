package com.storehub.service;

import com.storehub.dto.response.FacilityRevenueResponse;
import com.storehub.dto.response.RevenueReportResponse;
import com.storehub.dto.response.SystemRevenueSummaryResponse;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.UnitTypeRepository;
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
    @Mock FacilityRepository facilities;
    @Mock UnitTypeRepository unitTypes;
    @Mock com.storehub.repository.DepositDeductionRepository depositDeductions;
    @Mock com.storehub.entity.FacilityAccess access;
    @InjectMocks ReportServiceImpl report;
    @InjectMocks com.storehub.service.impl.FacilityManagementServiceImpl managerReport;

    @Test
    void facilityManagerRevenueIncludesTheSameRetainedDeposit() {
        UUID id = UUID.randomUUID();
        var facility = new com.storehub.entity.Facility(); facility.setId(id);
        when(facilities.findById(id)).thenReturn(java.util.Optional.of(facility));
        when(charges.sumPaidByFacility(id)).thenReturn(new BigDecimal("1000"));
        when(refunds.sumCompletedRentalRefundsByFacility(id)).thenReturn(new BigDecimal("300"));
        when(depositDeductions.sumRetainedByFacility(id)).thenReturn(new BigDecimal("200"));
        assertEquals(new BigDecimal("900"), managerReport.report(id, "manager@test.com").revenue());
    }

    @Test
    void retainedDepositIsRevenueInItsOwnPeriodAndPendingRefundStaysHeld() {
        UUID id = UUID.randomUUID();
        when(charges.sumRevenueByFacility(any(), any())).thenReturn(List.of());
        when(refunds.sumCompletedRefundsByFacility(any(), any())).thenReturn(List.of());
        when(charges.sumSystemRevenue(any(), any())).thenAnswer(call -> summary("0", "0", "0", 0));
        when(depositDeductions.reconcile(any(), any())).thenAnswer(call -> {
            int month = call.getArgument(0, java.time.LocalDateTime.class).getMonthValue();
            return List.of(new DepositTotals(id, month));
        });
        var january = report.getRevenueReport(LocalDate.of(2026,1,1), LocalDate.of(2026,1,31));
        var february = report.getRevenueReport(LocalDate.of(2026,2,1), LocalDate.of(2026,2,28));
        var march = report.getRevenueReport(LocalDate.of(2026,3,1), LocalDate.of(2026,3,31));
        assertEquals(BigDecimal.ZERO, january.getSystemSummary().getTotalRevenue());
        assertEquals(new BigDecimal("1000"), january.getSystemSummary().getDepositReconciliation().getClosingBalance());
        assertEquals(new BigDecimal("200"), february.getSystemSummary().getTotalRevenue());
        assertEquals(new BigDecimal("200"), february.getByFacility().get(0).getTotalRevenue());
        assertEquals(new BigDecimal("800"), february.getSystemSummary().getDepositReconciliation().getClosingBalance());
        assertEquals(BigDecimal.ZERO, march.getSystemSummary().getTotalRevenue());
        assertEquals(BigDecimal.ZERO, march.getSystemSummary().getDepositReconciliation().getClosingBalance());
    }

    private record DepositTotals(UUID id, int month) implements com.storehub.repository.DepositDeductionRepository.Totals {
        public UUID getFacilityId() { return id; }
        public String getFacilityName() { return "Test facility"; }
        public BigDecimal getOpeningBalance() { return new BigDecimal(month == 1 ? "0" : month == 2 ? "1000" : "800"); }
        public BigDecimal getReceived() { return month == 1 ? new BigDecimal("1000") : BigDecimal.ZERO; }
        public BigDecimal getRefunded() { return month == 3 ? new BigDecimal("800") : BigDecimal.ZERO; }
        public BigDecimal getRetained() { return month == 2 ? new BigDecimal("200") : BigDecimal.ZERO; }
        public BigDecimal getDamageRetained() { return getRetained(); }
        public BigDecimal getCancellationRetained() { return BigDecimal.ZERO; }
    }

    @Test
    void refundInFebruaryDoesNotRewriteJanuaryRevenue() {
        when(facilities.findAllByOrderByCreatedAtAsc()).thenReturn(List.of());
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
