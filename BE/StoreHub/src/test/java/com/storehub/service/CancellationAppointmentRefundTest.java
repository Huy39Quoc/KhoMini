package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.StorageUnit;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.PaymentServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CancellationAppointmentRefundTest {
    @Mock PaymentRepository payments;
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock RefundRequestRepository refunds;
    @Mock EmailService email;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock WaitlistService waitlist;
    @Mock FacilityPolicyRepository facilityPolicies;
    @InjectMocks PaymentServiceImpl service;

    @Test
    void calculatesCancellationAgainstActualCheckInHour() {
        UUID facilityId = UUID.randomUUID();
        Facility facility = Facility.builder().build();
        facility.setId(facilityId);
        LocalDate day = LocalDate.now().plusDays(2);
        LocalDateTime appointment = day.atTime(18, 0);
        Booking booking = Booking.builder()
                .startDate(day)
                .scheduledCheckInTime(appointment)
                .depositPaid(BigDecimal.valueOf(100))
                .storageUnit(StorageUnit.builder().facility(facility).build())
                .build();
        when(pricing.calculateCancellationRefund(eq(booking), eq(BigDecimal.valueOf(100)),
                eq(appointment), any(LocalDateTime.class)))
                .thenReturn(BigDecimal.ZERO);

        assertEquals(BigDecimal.ZERO, service.refundOnCancellation(booking));
        verify(pricing).calculateCancellationRefund(eq(booking), eq(BigDecimal.valueOf(100)),
                eq(appointment), any(LocalDateTime.class));
    }
}
