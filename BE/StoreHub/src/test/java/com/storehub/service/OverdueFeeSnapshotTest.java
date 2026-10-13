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

    @Test
    void returnWithinTheGracePeriodDoesNotCreateANewFee() {
        UUID bookingId = UUID.randomUUID(), facilityId = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(facilityId);
        Booking booking = Booking.builder()
                .storageUnit(StorageUnit.builder().facility(facility).build())
                .endDate(LocalDate.of(2026, 10, 12)).build();
        booking.setId(bookingId);
        when(policyService.getOverdueConfig(facilityId))
                .thenReturn(new OverdueConfigResponse(1, BigDecimal.valueOf(75), 4, 7));

        org.junit.jupiter.api.Assertions.assertFalse(scheduler.accrueOutstandingForCheckout(
                booking, LocalDateTime.of(2026, 10, 13, 0, 2)));
        org.mockito.Mockito.verifyNoInteractions(pricing);
        org.mockito.Mockito.verify(payments, org.mockito.Mockito.never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void checkoutAccruesMissedDaysAndDoesNotDuplicateTheFeeOnRetry() {
        UUID bookingId = UUID.randomUUID(), facilityId = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(facilityId);
        Booking booking = Booking.builder()
                .bookingCode("BK-MISSED")
                .storageUnit(StorageUnit.builder().facility(facility).build())
                .endDate(LocalDate.of(2026, 10, 10))
                .overdueFeeAccrued(BigDecimal.ZERO).build();
        booking.setId(bookingId);
        LocalDateTime returnTime = LocalDateTime.of(2026, 10, 13, 0, 2);
        when(policyService.getOverdueConfig(facilityId))
                .thenReturn(new OverdueConfigResponse(1, BigDecimal.valueOf(75), 4, 7));
        when(pricing.calculateLateFee(facilityId, 2)).thenReturn(new BigDecimal("150"));
        Payment outstanding = Payment.builder().status(PaymentStatus.PENDING)
                .note(OVERDUE_LATE_FEE).amount(new BigDecimal("150")).build();
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
        assertEquals(new BigDecimal("150"), saved.getValue().getAmount());
        assertEquals(PaymentStatus.PENDING, saved.getValue().getStatus());
        assertEquals(new BigDecimal("150"), booking.getOverdueFeeAccrued());
        verify(bookings, times(2)).save(booking);
    }

    @Test
    void nextDayAccrualDoesNotChangeAmountOfAlreadyIssuedGatewayUrl() {
        UUID bookingId = UUID.randomUUID();
        UUID facilityId = UUID.randomUUID();
        Booking booking = Booking.builder().overdueFeeAccrued(new BigDecimal("100")).build();
        booking.setId(bookingId);
        Payment issued = Payment.builder().booking(booking).transactionId("OD-OLD")
                .paymentType(PaymentType.EXTRA_CHARGE).status(PaymentStatus.PENDING)
                .note(OVERDUE_LATE_FEE).paymentTime(LocalDateTime.now().minusDays(1))
                .amount(new BigDecimal("100")).gatewayAmount(new BigDecimal("100"))
                .gatewayCreateDate("20261008123000").build();
        when(pricing.calculateLateFee(facilityId, 2)).thenReturn(new BigDecimal("150"));
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                bookingId, PaymentType.EXTRA_CHARGE, PaymentStatus.PENDING, OVERDUE_LATE_FEE))
                .thenReturn(Optional.of(issued));

        ReflectionTestUtils.invokeMethod(scheduler, "updateLateFee", booking, facilityId,
                2L, LocalDateTime.now());

        ArgumentCaptor<Payment> saved = ArgumentCaptor.forClass(Payment.class);
        verify(payments).save(saved.capture());
        assertNotEquals(issued.getTransactionId(), saved.getValue().getTransactionId());
        assertEquals(new BigDecimal("50"), saved.getValue().getAmount());
        assertEquals(new BigDecimal("100"), issued.getAmount());
        assertEquals(new BigDecimal("100"), issued.getGatewayAmount());
        assertEquals(new BigDecimal("150"), booking.getOverdueFeeAccrued());
    }

    @Test
    void schedulerRestoresOldFailedDebtAndAccruesOnlyNewDays() {
        UUID bookingId = UUID.randomUUID(), facilityId = UUID.randomUUID();
        Booking booking = Booking.builder().overdueFeeAccrued(new BigDecimal("100")).build();
        booking.setId(bookingId);
        Payment failed = Payment.builder().booking(booking).transactionId("OD-FAILED")
                .paymentType(PaymentType.EXTRA_CHARGE).status(PaymentStatus.FAILED)
                .note(OVERDUE_LATE_FEE).paymentTime(LocalDateTime.now().minusDays(1))
                .amount(new BigDecimal("100")).build();
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                bookingId, PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                List.of(PaymentStatus.FAILED))).thenReturn(List.of(failed));
        when(pricing.calculateLateFee(facilityId, 2)).thenReturn(new BigDecimal("150"));

        ReflectionTestUtils.invokeMethod(scheduler, "updateLateFee", booking, facilityId,
                2L, LocalDateTime.now());

        ArgumentCaptor<Payment> saved = ArgumentCaptor.forClass(Payment.class);
        verify(payments, times(3)).save(saved.capture());
        assertNotNull(failed.getVoidedAt());
        assertEquals(new BigDecimal("100"), saved.getAllValues().get(1).getAmount());
        assertEquals(PaymentStatus.PENDING, saved.getAllValues().get(1).getStatus());
        assertEquals(new BigDecimal("50"), saved.getAllValues().get(2).getAmount());
        assertEquals(new BigDecimal("150"), booking.getOverdueFeeAccrued());
    }
}
