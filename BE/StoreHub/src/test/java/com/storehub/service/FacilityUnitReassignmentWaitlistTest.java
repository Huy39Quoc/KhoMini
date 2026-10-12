package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.FacilityAccess;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.UnitType;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.service.impl.FacilityManagementServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FacilityUnitReassignmentWaitlistTest {
    @Mock FacilityAccess access;
    @Mock BookingRepository bookings;
    @Mock StorageUnitRepository units;
    @Mock WaitlistService waitlist;
    @InjectMocks FacilityManagementServiceImpl service;

    @Test
    void reassignmentImmediatelyOffersReleasedUnitToWaitlist() {
        UUID facilityId = UUID.randomUUID(), typeId = UUID.randomUUID();
        UUID bookingId = UUID.randomUUID(), oldId = UUID.randomUUID(), newId = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(facilityId);
        UnitType type = UnitType.builder().typeName("Small").build(); type.setId(typeId);
        StorageUnit oldUnit = StorageUnit.builder().facility(facility).unitType(type)
                .unitCode("A-1").status(UnitStatus.RESERVED).build(); oldUnit.setId(oldId);
        StorageUnit replacement = StorageUnit.builder().facility(facility).unitType(type)
                .unitCode("A-2").status(UnitStatus.AVAILABLE).build(); replacement.setId(newId);
        Booking booking = Booking.builder().status(BookingStatus.CONFIRMED)
                .storageUnit(oldUnit).build(); booking.setId(bookingId);
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));
        when(units.lockById(newId)).thenReturn(Optional.of(replacement));

        service.assignUnit(facilityId, bookingId, newId, "manager@test.com");

        assertEquals(UnitStatus.AVAILABLE, oldUnit.getStatus());
        assertEquals(UnitStatus.RESERVED, replacement.getStatus());
        assertEquals(replacement, booking.getStorageUnit());
        verify(waitlist).notifyNextInWaitlist(facilityId, typeId);
    }
}
