package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.scheduler.OverdueScheduler;
import com.storehub.dto.response.OverdueConfigResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.StorageUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import java.util.List;

import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.doReturn;

@ExtendWith(MockitoExtension.class)
class OverdueFeeSnapshotTest {
    @Mock BookingRepository bookings;
    @Mock PaymentRepository payments;
    @Mock FacilityPolicyRepository policies;
    @Mock FacilityPolicyService policyService;
    @Mock PricingService pricing;
    @Mock ActivityLogService logs;
    @InjectMocks OverdueScheduler scheduler;

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(strings = {"100000.00", "10000.00", "0.00"})
    void policyEditsNeverRepriceExistingDaysOrChangeGracePeriod(String newRate) {
        UUID facilityId = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(facilityId);
        // The contract has already accrued two chargeable days at its agreed rate.
        Booking booking = Booking.builder().bookingCode("BK-FROZEN")
                .storageUnit(StorageUnit.builder().facility(facility).build())
                .endDate(LocalDate.of(2026, 10, 10))
                .overdueDailyLateFee(new BigDecimal("50000.00"))
                .overdueGraceDays(1).overdueAccessDisableDays(5).overdueSealingDays(7)
                .overdueFeeAccrued(new BigDecimal("100000.00")).build();
        booking.setId(UUID.randomUUID());
        com.storehub.entity.FacilityPolicy livePolicy = com.storehub.entity.FacilityPolicy.builder()
                .dailyLateFee(new BigDecimal(newRate)).overdueGraceDays(0)
                .overdueAccessDisableDays(1).overdueSealingDays(1).build();
        // If the old implementation consults mutable policy, the regression must fail.
        org.mockito.Mockito.lenient().when(policyService.getOverdueConfig(facilityId))
                .thenReturn(new OverdueConfigResponse(livePolicy.getOverdueGraceDays(),
                        livePolicy.getDailyLateFee(), 1, 1));
        org.mockito.Mockito.lenient().when(pricing.calculateLateFee(
                org.mockito.ArgumentMatchers.eq(facilityId), org.mockito.ArgumentMatchers.anyLong()))
                .thenAnswer(call -> livePolicy.getDailyLateFee().multiply(BigDecimal.valueOf(call.getArgument(1, Long.class))));

        LocalDateTime now = LocalDateTime.of(2026, 10, 14, 0, 5);
        ReflectionTestUtils.invokeMethod(scheduler, "processOneBooking", booking, now.toLocalDate(), now);
        // Checkout/extension catch-up uses the same terms and must not bill again.
        scheduler.accrueOutstandingForCheckout(booking, now);
        ReflectionTestUtils.invokeMethod(scheduler, "processOneBooking", booking, now.toLocalDate(), now);

        ArgumentCaptor<Payment> saved = ArgumentCaptor.forClass(Payment.class);
        verify(payments).save(saved.capture());
        assertEquals(new BigDecimal("50000.00"), saved.getValue().getAmount());
        assertEquals(new BigDecimal("150000.00"), booking.getOverdueFeeAccrued());
        org.junit.jupiter.api.Assertions.assertNull(booking.getAccessDisabledAt());
        org.junit.jupiter.api.Assertions.assertNull(booking.getSealingPendingAt());
        org.mockito.Mockito.verifyNoInteractions(policyService, pricing, policies);
    }

    @Test
    void missingSnapshotCannotSilentlyUseTheCurrentPolicy() {
        Booking booking = Booking.builder().endDate(LocalDate.of(2026, 10, 10)).build();
        org.junit.jupiter.api.Assertions.assertThrows(com.storehub.exception.AppException.class,
                () -> scheduler.accrueOutstandingForCheckout(booking, LocalDateTime.of(2026, 10, 14, 0, 5)));
        org.mockito.Mockito.verifyNoInteractions(policyService, pricing, payments);
    }

    @Test
    void returnWithinTheGracePeriodDoesNotCreateANewFee() {
        UUID bookingId = UUID.randomUUID(), facilityId = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(facilityId);
        Booking booking = Booking.builder().overdueDailyLateFee(new BigDecimal("75.00"))
                .overdueGraceDays(1).overdueAccessDisableDays(4).overdueSealingDays(7)
                .storageUnit(StorageUnit.builder().facility(facility).build())
                .endDate(LocalDate.of(2026, 10, 12)).build();
        booking.setId(bookingId);

        org.junit.jupiter.api.Assertions.assertFalse(scheduler.accrueOutstandingForCheckout(
                booking, LocalDateTime.of(2026, 10, 13, 0, 2)));
        org.mockito.Mockito.verifyNoInteractions(pricing);
        org.mockito.Mockito.verify(payments, org.mockito.Mockito.never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void checkoutAccruesMissedDaysAndDoesNotDuplicateTheFeeOnRetry() {
        UUID bookingId = UUID.randomUUID(), facilityId = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(facilityId);
        Booking booking = Booking.builder().overdueDailyLateFee(new BigDecimal("75.00"))
                .overdueGraceDays(1).overdueAccessDisableDays(4).overdueSealingDays(7)
                .bookingCode("BK-MISSED")
                .storageUnit(StorageUnit.builder().facility(facility).build())
                .endDate(LocalDate.of(2026, 10, 10))
                .overdueFeeAccrued(BigDecimal.ZERO).build();
        booking.setId(bookingId);
        LocalDateTime returnTime = LocalDateTime.of(2026, 10, 13, 0, 2);
        Payment outstanding = Payment.builder().status(PaymentStatus.PENDING)
                .note(OVERDUE_LATE_FEE).amount(new BigDecimal("150.00")).build();
        doReturn(List.of()).when(payments).findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                bookingId, PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                List.of(PaymentStatus.FAILED));
        doReturn(List.of(outstanding)).when(payments).findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                bookingId, PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                List.of(PaymentStatus.PENDING, PaymentStatus.FAILED));

        assertTrue(scheduler.accrueOutstandingForCheckout(booking, returnTime));
        assertTrue(scheduler.accrueOutstandingForCheckout(booking, returnTime));

        ArgumentCaptor<Payment> saved = ArgumentCaptor.forClass(Payment.class);
        verify(payments).save(saved.capture());
        assertEquals(new BigDecimal("150.00"), saved.getValue().getAmount());
        assertEquals(PaymentStatus.PENDING, saved.getValue().getStatus());
        assertEquals(new BigDecimal("150.00"), booking.getOverdueFeeAccrued());
        verify(bookings, times(2)).save(booking);
    }

    @Test
    void nextDayAccrualDoesNotChangeAmountOfAlreadyIssuedGatewayUrl() {
        UUID bookingId = UUID.randomUUID();
        UUID facilityId = UUID.randomUUID();
        Booking booking = Booking.builder().overdueDailyLateFee(new BigDecimal("75.00"))
                .overdueGraceDays(1).overdueAccessDisableDays(4).overdueSealingDays(7).overdueFeeAccrued(new BigDecimal("100")).build();
        booking.setId(bookingId);
        Payment issued = Payment.builder().booking(booking).transactionId("OD-OLD")
                .paymentType(PaymentType.EXTRA_CHARGE).status(PaymentStatus.PENDING)
                .note(OVERDUE_LATE_FEE).paymentTime(LocalDateTime.now().minusDays(1))
                .amount(new BigDecimal("100")).gatewayAmount(new BigDecimal("100"))
                .gatewayCreateDate("20261008123000").build();
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                bookingId, PaymentType.EXTRA_CHARGE, PaymentStatus.PENDING, OVERDUE_LATE_FEE))
                .thenReturn(Optional.of(issued));

        ReflectionTestUtils.invokeMethod(scheduler, "updateLateFee", booking,
                2L, LocalDateTime.now());

        ArgumentCaptor<Payment> saved = ArgumentCaptor.forClass(Payment.class);
        verify(payments).save(saved.capture());
        assertNotEquals(issued.getTransactionId(), saved.getValue().getTransactionId());
        assertEquals(new BigDecimal("50.00"), saved.getValue().getAmount());
        assertEquals(new BigDecimal("100"), issued.getAmount());
        assertEquals(new BigDecimal("100"), issued.getGatewayAmount());
        assertEquals(new BigDecimal("150.00"), booking.getOverdueFeeAccrued());
    }

    @Test
    void schedulerRestoresOldFailedDebtAndAccruesOnlyNewDays() {
        UUID bookingId = UUID.randomUUID(), facilityId = UUID.randomUUID();
        Booking booking = Booking.builder().overdueDailyLateFee(new BigDecimal("75.00"))
                .overdueGraceDays(1).overdueAccessDisableDays(4).overdueSealingDays(7).overdueFeeAccrued(new BigDecimal("100")).build();
        booking.setId(bookingId);
        Payment failed = Payment.builder().booking(booking).transactionId("OD-FAILED")
                .paymentType(PaymentType.EXTRA_CHARGE).status(PaymentStatus.FAILED)
                .note(OVERDUE_LATE_FEE).paymentTime(LocalDateTime.now().minusDays(1))
                .amount(new BigDecimal("100")).build();
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                bookingId, PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                List.of(PaymentStatus.FAILED))).thenReturn(List.of(failed));

        ReflectionTestUtils.invokeMethod(scheduler, "updateLateFee", booking,
                2L, LocalDateTime.now());

        ArgumentCaptor<Payment> saved = ArgumentCaptor.forClass(Payment.class);
        verify(payments, times(3)).save(saved.capture());
        assertNotNull(failed.getVoidedAt());
        assertEquals(new BigDecimal("100"), saved.getAllValues().get(1).getAmount());
        assertEquals(PaymentStatus.PENDING, saved.getAllValues().get(1).getStatus());
        assertEquals(new BigDecimal("50.00"), saved.getAllValues().get(2).getAmount());
        assertEquals(new BigDecimal("150.00"), booking.getOverdueFeeAccrued());
    }
}
