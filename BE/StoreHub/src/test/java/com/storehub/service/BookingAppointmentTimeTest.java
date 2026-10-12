package com.storehub.service;

import com.storehub.dto.request.BookingCreationRequest;
import com.storehub.entity.*;
import com.storehub.exception.*;
import com.storehub.repository.*;
import com.storehub.service.impl.BookingServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BookingAppointmentTimeTest {
    @Mock BookingRepository bookings;
    @Mock PaymentRepository payments;
    @Mock FacilityRepository facilities;
    @Mock StorageUnitRepository units;
    @Mock UserRepository users;
    @Mock PricingService pricing;
    @Mock WaitlistService waitlist;
    @Mock FacilityPolicyService policy;
    @Mock PaymentService paymentService;
    @InjectMocks BookingServiceImpl service;

    @Test
    void bookingRejectsCheckInOutsideFacilityHoursBeforeClaimingAUnit() {
        UUID facilityId = UUID.randomUUID(), typeId = UUID.randomUUID();
        Facility facility = Facility.builder().openTime(LocalTime.of(8, 0))
                .closeTime(LocalTime.of(20, 0)).build();
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(new User()));
        when(facilities.findById(facilityId)).thenReturn(Optional.of(facility));
        var request = BookingCreationRequest.builder().facilityId(facilityId)
                .unitTypeId(typeId).startDate(LocalDate.now().plusDays(1))
                .checkInTime(LocalTime.of(22, 0)).rentalMonths(1).build();

        AppException error = assertThrows(AppException.class,
                () -> service.createBooking("customer@test.com", request));

        assertEquals(ErrorCode.INVALID_REQUEST, error.getErrorCode());
        verify(units, never()).claimAvailableUnitId(any(), any());
    }
}
