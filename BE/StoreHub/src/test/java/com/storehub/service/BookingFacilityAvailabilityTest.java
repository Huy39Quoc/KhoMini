package com.storehub.service;

import com.storehub.dto.request.BookingCreationRequest;
import com.storehub.entity.Facility;
import com.storehub.entity.User;
import com.storehub.enums.FacilityStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.BookingServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BookingFacilityAvailabilityTest {
    @Mock BookingRepository bookings;
    @Mock FacilityRepository facilities;
    @Mock StorageUnitRepository units;
    @Mock UserRepository users;
    @Mock PricingService pricing;
    @Mock WaitlistService waitlist;
    @Mock FacilityPolicyService policies;
    @Mock PaymentService payments;
    @InjectMocks BookingServiceImpl bookingService;

    @Test
    void doesNotReserveAUnitInAFacilityUnderMaintenance() {
        UUID facilityId = UUID.randomUUID();
        UUID unitTypeId = UUID.randomUUID();
        Facility facility = Facility.builder().status(FacilityStatus.MAINTENANCE).build();
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(new User()));
        when(facilities.findById(facilityId)).thenReturn(Optional.of(facility));

        BookingCreationRequest request = BookingCreationRequest.builder()
                .facilityId(facilityId)
                .unitTypeId(unitTypeId)
                .startDate(LocalDate.now().plusDays(1))
                .rentalMonths(1)
                .build();

        AppException exception = assertThrows(AppException.class,
                () -> bookingService.createBooking("customer@test.com", request));

        assertEquals(ErrorCode.FACILITY_NOT_ACTIVE, exception.getErrorCode());
        verify(units, never()).claimAvailableUnitId(any(), any());
    }
}
