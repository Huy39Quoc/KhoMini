package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.scheduler.OverdueScheduler;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

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
}
