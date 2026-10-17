package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.Payment;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.UnitType;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.BookingServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PendingBookingRecoveryTest {
    @Mock BookingRepository bookings;
    @Mock PaymentRepository paymentRepository;
    @Mock FacilityRepository facilities;
    @Mock StorageUnitRepository units;
    @Mock UserRepository users;
    @Mock PricingService pricing;
    @Mock WaitlistService waitlist;
    @Mock FacilityPolicyService policies;
    @Mock PaymentService payments;
    @InjectMocks BookingServiceImpl service;

    @Test
    void loadsOnlyTheAuthenticatedCustomersStillPayableBookingsAndUsesChargeSnapshot() {
        UUID customerId = UUID.randomUUID();
        UUID facilityId = UUID.randomUUID();
        User customer = new User();
        customer.setId(customerId);
        Facility facility = Facility.builder().name("Central").build();
        facility.setId(facilityId);
        UnitType type = UnitType.builder()
                .typeName("Small").dimensions("2x2")
                .depositAmount(new BigDecimal("100000"))
                .build();
        StorageUnit unit = StorageUnit.builder()
                .unitCode("A-01").facility(facility).unitType(type).build();
        Booking booking = Booking.builder().bookingCode("BK-1")
                .storageUnit(unit).status(BookingStatus.PENDING_PAYMENT)
                .startDate(LocalDate.now().plusDays(1)).rentalMonths(2)
                .totalRentalFee(new BigDecimal("500000"))
                .expiresAt(LocalDateTime.now().plusMinutes(15)).build();
        booking.setId(UUID.randomUUID());
        when(users.findByEmail("owner@example.com")).thenReturn(Optional.of(customer));
        when(bookings.findPayableBookingsByCustomerId(eq(customerId),
                eq(BookingStatus.PENDING_PAYMENT), any(LocalDateTime.class)))
                .thenReturn(List.of(booking));
        when(pricing.calculateDepositAmount(facilityId,
                new BigDecimal("500000"), new BigDecimal("100000")))
                .thenReturn(new BigDecimal("200000"));
        when(pricing.calculateManagementFee(facilityId, 2))
                .thenReturn(new BigDecimal("20000"));
        when(paymentRepository.findByBooking_IdAndStatusAndPaymentTypeIn(
                eq(booking.getId()), eq(PaymentStatus.PENDING), any()))
                .thenReturn(List.of(
                        Payment.builder().paymentType(PaymentType.DEPOSIT)
                                .amount(new BigDecimal("300000"))
                                .gatewayAmount(new BigDecimal("850000")).build(),
                        Payment.builder().paymentType(PaymentType.RENTAL_FEE)
                                .amount(new BigDecimal("550000")).build()));

        var result = service.getPayableBookings("owner@example.com");

        assertEquals(1, result.size());
        assertEquals("Central", result.get(0).getFacilityName());
        assertEquals("Small", result.get(0).getUnitTypeName());
        assertEquals(new BigDecimal("300000"), result.get(0).getDepositAmount());
        assertEquals(new BigDecimal("50000"), result.get(0).getTotalExtraFees());
        assertEquals(new BigDecimal("850000"), result.get(0).getInitialPaymentAmount());
        verify(bookings).findPayableBookingsByCustomerId(eq(customerId),
                eq(BookingStatus.PENDING_PAYMENT), any(LocalDateTime.class));
    }
}
