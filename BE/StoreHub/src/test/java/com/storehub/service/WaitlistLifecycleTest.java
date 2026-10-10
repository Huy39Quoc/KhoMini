package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.repository.*;
import com.storehub.service.impl.WaitlistServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WaitlistLifecycleTest {
    @Mock WaitlistRepository entries;
    @Mock UserRepository users;
    @Mock FacilityRepository facilities;
    @Mock UnitTypeRepository types;
    @Mock StorageUnitRepository units;
    @Mock EmailService email;
    @InjectMocks WaitlistServiceImpl service;

    @Test
    void expiredOfferAdvancesToNextCustomerOnlyWhenUnitIsAvailable() {
        UUID facilityId = UUID.randomUUID(), typeId = UUID.randomUUID();
        Facility facility = Facility.builder().name("Central").build();
        facility.setId(facilityId);
        UnitType type = UnitType.builder().typeName("Small").build();
        type.setId(typeId);
        User first = User.builder().email("first@test.com").fullName("First").build();
        User second = User.builder().email("second@test.com").fullName("Second").build();
        Waitlist expired = Waitlist.builder().customer(first).facility(facility).unitType(type)
                .status(WaitlistStatus.NOTIFIED).offerExpiresAt(Instant.now().minusSeconds(1)).build();
        Waitlist next = Waitlist.builder().customer(second).facility(facility).unitType(type)
                .status(WaitlistStatus.WAITING).build();
        when(units.existsByFacility_IdAndUnitType_IdAndStatus(facilityId, typeId, UnitStatus.AVAILABLE))
                .thenReturn(true);
        when(entries.findOpenForUpdate(facilityId, typeId,
                List.of(WaitlistStatus.WAITING, WaitlistStatus.NOTIFIED)))
                .thenReturn(List.of(expired, next));

        service.notifyNextInWaitlist(facilityId, typeId);

        assertEquals(WaitlistStatus.EXPIRED, expired.getStatus());
        assertEquals(WaitlistStatus.NOTIFIED, next.getStatus());
        verify(email).sendWaitlistNotificationEmail("second@test.com", "Second", "Central", "Small");
        verify(entries).save(next);
    }

    @Test
    void activeOfferDoesNotSendAnotherNotice() {
        UUID facilityId = UUID.randomUUID(), typeId = UUID.randomUUID();
        Waitlist active = Waitlist.builder().status(WaitlistStatus.NOTIFIED)
                .offerExpiresAt(Instant.now().plusSeconds(3600)).build();
        when(units.existsByFacility_IdAndUnitType_IdAndStatus(facilityId, typeId, UnitStatus.AVAILABLE))
                .thenReturn(true);
        when(entries.findOpenForUpdate(facilityId, typeId,
                List.of(WaitlistStatus.WAITING, WaitlistStatus.NOTIFIED)))
                .thenReturn(List.of(active));

        service.notifyNextInWaitlist(facilityId, typeId);

        verifyNoInteractions(email);
        verify(entries, never()).save(any());
    }

    @Test
    void schedulerRetriesWaitingCustomerAfterEmailFailureWhenUnitIsStillFree() {
        UUID facilityId = UUID.randomUUID(), typeId = UUID.randomUUID();
        Facility facility = Facility.builder().name("Central").build();
        facility.setId(facilityId);
        UnitType type = UnitType.builder().typeName("Small").build();
        type.setId(typeId);
        Waitlist waiting = Waitlist.builder()
                .customer(User.builder().email("customer@test.com").fullName("Customer").build())
                .facility(facility).unitType(type).status(WaitlistStatus.WAITING).build();
        when(entries.findExpiredOffersForUpdate(eq(WaitlistStatus.NOTIFIED), any(Instant.class)))
                .thenReturn(List.of());
        when(entries.findWaitingPairs(WaitlistStatus.WAITING))
                .thenReturn(java.util.Collections.singletonList(new Object[]{facilityId, typeId}));
        when(units.existsByFacility_IdAndUnitType_IdAndStatus(facilityId, typeId, UnitStatus.AVAILABLE))
                .thenReturn(true);
        when(entries.findOpenForUpdate(facilityId, typeId,
                List.of(WaitlistStatus.WAITING, WaitlistStatus.NOTIFIED)))
                .thenReturn(List.of(waiting));

        service.expireStaleNotifications();

        assertEquals(WaitlistStatus.NOTIFIED, waiting.getStatus());
        verify(email).sendWaitlistNotificationEmail("customer@test.com", "Customer", "Central", "Small");
    }
}
