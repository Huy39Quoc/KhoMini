package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.FacilityOperationsServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AppointmentConflictTest {
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock FacilityAccess access;
    @InjectMocks FacilityOperationsServiceImpl operations;
    Booking booking;
    User staff;
    Facility facility;
    LocalDate day = LocalDate.of(2026, 11, 5);

    @BeforeEach
    void setup() {
        facility = Facility.builder().openTime(LocalTime.of(8, 30)).build();
        facility.setId(UUID.randomUUID());
        staff = User.builder().facility(facility).role(Role.builder().name("STAFF").build()).build();
        staff.setId(UUID.randomUUID());
        booking = Booking.builder().status(BookingStatus.CONFIRMED).startDate(day).endDate(day.plusMonths(1))
                .scheduledCheckInTime(day.atTime(9, 0, 30)).scheduledReturnTime(day.atTime(9, 0, 45))
                .storageUnit(StorageUnit.builder().facility(facility).build()).build();
        booking.setId(UUID.randomUUID());
        User manager = User.builder().role(Role.builder().name("FACILITY_MANAGER").build()).build();
        when(access.require("manager@test.com", facility.getId())).thenReturn(manager);
        when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
    }

    @ParameterizedTest
    @ValueSource(strings = {"CHECK_IN", "CHECK_OUT"})
    void conflictingAppointmentIsRejectedWithoutReplacingThePreviousAssignee(String type) {
        if (type.equals("CHECK_OUT")) booking.setStatus(BookingStatus.ACTIVE);
        User previous = new User();
        booking.setAssignedCheckInStaff(previous);
        booking.setAssignedCheckOutStaff(previous);
        when(users.findByIdForUpdate(staff.getId())).thenReturn(Optional.of(staff));
        when(bookings.existsConflictingStaffAppointment(staff.getId(), booking.getId(),
                day.atTime(9, 0), day.atTime(9, 1))).thenReturn(true);
        AppException error = assertThrows(AppException.class, () -> assign(type, staff.getId()));
        assertEquals(ErrorCode.STAFF_APPOINTMENT_CONFLICT, error.getErrorCode());
        assertEquals(409, error.getErrorCode().getHttpStatus().value());
        assertSame(previous, booking.getAssignedCheckInStaff());
        assertSame(previous, booking.getAssignedCheckOutStaff());
        verify(bookings, never()).save(any());
    }

    @Test
    void staffIsLockedBeforeCheckingTheMinuteAndSavingTheAssignment() {
        when(users.findByIdForUpdate(staff.getId())).thenReturn(Optional.of(staff));
        assign("CHECK_IN", staff.getId());
        var order = inOrder(users, bookings);
        order.verify(users).findByIdForUpdate(staff.getId());
        order.verify(bookings).existsConflictingStaffAppointment(staff.getId(), booking.getId(),
                day.atTime(9, 0), day.atTime(9, 1));
        order.verify(bookings).save(booking);
        assertSame(staff, booking.getAssignedCheckInStaff());
    }

    @ParameterizedTest
    @ValueSource(strings = {"CHECK_IN", "CHECK_OUT"})
    void legacyAppointmentsUseTheSameFallbackTimeAsTheDisplayedSchedule(String type) {
        if (type.equals("CHECK_OUT")) booking.setStatus(BookingStatus.ACTIVE);
        booking.setScheduledCheckInTime(null);
        booking.setScheduledReturnTime(null);
        when(users.findByIdForUpdate(staff.getId())).thenReturn(Optional.of(staff));
        assign(type, staff.getId());
        LocalDateTime expected = type.equals("CHECK_IN") ? day.atTime(8, 30) : day.plusMonths(1).atTime(9, 0);
        verify(bookings).existsConflictingStaffAppointment(staff.getId(), booking.getId(), expected, expected.plusMinutes(1));
    }

    @Test
    void unassigningDoesNotRequireAFreeAppointmentSlot() {
        booking.setAssignedCheckInStaff(staff);
        assign("CHECK_IN", null);
        assertNull(booking.getAssignedCheckInStaff());
        verifyNoInteractions(users);
        verify(bookings, never()).existsConflictingStaffAppointment(any(), any(), any(), any());
        verify(bookings).save(booking);
    }

    private void assign(String type, UUID staffId) {
        operations.assignAppointment(booking.getId(), facility.getId(), "manager@test.com", type, staffId);
    }
}
