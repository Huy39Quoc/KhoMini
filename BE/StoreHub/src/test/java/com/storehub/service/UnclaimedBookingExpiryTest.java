package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.scheduler.UnclaimedBookingExpiryScheduler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UnclaimedBookingExpiryTest {
    @Mock BookingRepository bookings;
    @Mock StorageUnitRepository units;
    @Mock PaymentService payments;
    @Mock WaitlistService waitlist;
    @Mock ActivityLogService logs;
    @Mock PlatformTransactionManager manager;
    @InjectMocks UnclaimedBookingExpiryScheduler scheduler;

    Booking booking;
    StorageUnit unit;
    LocalDate today = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));

    @BeforeEach
    void prepare() {
        Facility facility = new Facility(); facility.setId(UUID.randomUUID());
        UnitType type = new UnitType(); type.setId(UUID.randomUUID());
        unit = StorageUnit.builder().facility(facility).unitType(type).status(UnitStatus.RESERVED).build();
        unit.setId(UUID.randomUUID());
        booking = Booking.builder().bookingCode("BK-NO-SHOW").storageUnit(unit)
                .status(BookingStatus.CONFIRMED).endDate(today).assignedCheckInStaff(new User()).build();
        booking.setId(UUID.randomUUID());
        when(bookings.findExpiredUnclaimedBookingIds(today)).thenReturn(List.of(booking.getId()));
        when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
        when(manager.getTransaction(any())).thenAnswer(call -> new SimpleTransactionStatus());
    }

    @Test
    void expiresAtTheSameBoundaryAsCheckInAndNotifiesOnlyAfterCommit() {
        when(units.lockById(unit.getId())).thenReturn(Optional.of(unit));
        scheduler.expireUnclaimedBookings();
        assertEquals(BookingStatus.CANCELLED, booking.getStatus());
        assertEquals(UnitStatus.AVAILABLE, unit.getStatus());
        assertNull(booking.getAssignedCheckInStaff());
        assertNull(booking.getReturnTime()); // No physical return happened.
        var order = inOrder(payments, bookings, units, manager, waitlist);
        order.verify(payments).refundOnCancellation(booking);
        order.verify(bookings).save(booking);
        order.verify(units).save(unit);
        order.verify(manager).commit(any());
        order.verify(waitlist).notifyNextInWaitlist(unit.getFacility().getId(), unit.getUnitType().getId());
        verify(logs).recordSystem(eq(ActivityAction.RESERVATION_EXPIRE), eq("BOOKING"),
                eq(booking.getId()), contains("without handover"));
        scheduler.expireUnclaimedBookings();
        verify(payments, times(1)).refundOnCancellation(booking);
        verify(units, times(1)).save(unit);
        verify(waitlist, times(1)).notifyNextInWaitlist(any(), any());
    }

    @ParameterizedTest
    @EnumSource(value = BookingStatus.class, names = {"ACTIVE", "COMPLETED", "CANCELLED", "PENDING_PAYMENT"})
    void rechecksStatusUnderLockSoConcurrentCheckInOrCancellationIsSafe(BookingStatus status) {
        booking.setStatus(status);
        scheduler.expireUnclaimedBookings();
        verifyNoInteractions(units, payments, waitlist, logs);
        verify(bookings, never()).save(any());
    }

    @Test
    void doesNotCancelAContractBeforeItsEndDate() {
        booking.setEndDate(today.plusDays(1));
        scheduler.expireUnclaimedBookings();
        assertEquals(BookingStatus.CONFIRMED, booking.getStatus());
        verifyNoInteractions(units, payments, waitlist, logs);
    }

    @Test
    void neverReleasesABookingWithHandoverEvidence() {
        booking.setHandoverTime(LocalDateTime.now().minusDays(1));
        scheduler.expireUnclaimedBookings();
        verifyNoInteractions(units, payments, waitlist, logs);
        booking.setHandoverTime(null);
        booking.setHandedOverByStaffId(UUID.randomUUID());
        scheduler.expireUnclaimedBookings();
        verifyNoInteractions(units, payments, waitlist, logs);
    }

    @Test
    void maintenanceUnitIsNotPutOnSaleAfterUnclaimedReservationExpires() {
        unit.setStatus(UnitStatus.UNDER_MAINTENANCE);
        when(units.lockById(unit.getId())).thenReturn(Optional.of(unit));
        scheduler.expireUnclaimedBookings();
        assertEquals(BookingStatus.CANCELLED, booking.getStatus());
        assertEquals(UnitStatus.UNDER_MAINTENANCE, unit.getStatus());
        verify(payments).refundOnCancellation(booking);
        verify(units, never()).save(any());
        verifyNoInteractions(waitlist);
    }

    @Test
    void inconsistentOccupiedUnitIsLeftForInspection() {
        unit.setStatus(UnitStatus.OCCUPIED);
        when(units.lockById(unit.getId())).thenReturn(Optional.of(unit));
        scheduler.expireUnclaimedBookings();
        assertEquals(BookingStatus.CONFIRMED, booking.getStatus());
        assertEquals(UnitStatus.OCCUPIED, unit.getStatus());
        verify(manager).rollback(any());
        verifyNoInteractions(payments, waitlist, logs);
    }

    @Test
    void neverReleasesAUnitHeldByAnotherOpenBooking() {
        when(units.lockById(unit.getId())).thenReturn(Optional.of(unit));
        when(bookings.existsByStorageUnit_IdAndStatusInAndIdNot(eq(unit.getId()), anyList(), eq(booking.getId())))
                .thenReturn(true);
        scheduler.expireUnclaimedBookings();
        assertEquals(BookingStatus.CONFIRMED, booking.getStatus());
        assertEquals(UnitStatus.RESERVED, unit.getStatus());
        verify(manager).rollback(any());
        verifyNoInteractions(payments, waitlist, logs);
    }

    @Test
    void settlementFailureRollsBackAndDoesNotBlockOtherBookings() {
        when(units.lockById(unit.getId())).thenReturn(Optional.of(unit));
        doThrow(new IllegalStateException("Financial record requires review"))
                .when(payments).refundOnCancellation(booking);
        Booking other = Booking.builder().bookingCode("BK-OTHER").status(BookingStatus.CONFIRMED)
                .endDate(today.minusDays(3)).storageUnit(unit).build();
        other.setId(UUID.randomUUID());
        when(bookings.findExpiredUnclaimedBookingIds(today)).thenReturn(List.of(booking.getId(), other.getId()));
        when(bookings.lockById(other.getId())).thenReturn(Optional.of(other));
        scheduler.expireUnclaimedBookings();
        assertEquals(BookingStatus.CONFIRMED, booking.getStatus());
        assertEquals(BookingStatus.CANCELLED, other.getStatus());
        verify(manager).rollback(any());
        verify(manager).commit(any());
        verify(bookings, never()).save(booking);
        verify(bookings).save(other);
    }
}
