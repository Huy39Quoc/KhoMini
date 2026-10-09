package com.storehub.service;

import com.storehub.dto.request.HandoverRequest;
import com.storehub.entity.*;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.*;
import com.storehub.service.impl.FacilityOperationsServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AppointmentAssignmentTest {
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock HandoverRecordRepository records;
    @Mock StorageUnitRepository units;
    @Mock FacilityAccess access;
    @Mock PaymentService payments;
    @Mock WaitlistService waitlist;
    @Mock org.springframework.security.crypto.password.PasswordEncoder encoder;
    @Mock ActivityLogService logs;
    @InjectMocks FacilityOperationsServiceImpl operations;

    @Test
    void otherStaffCannotCheckOutAnAssignedAppointment() {
        UUID facilityId = UUID.randomUUID();
        UUID bookingId = UUID.randomUUID();
        Facility facility = new Facility();
        facility.setId(facilityId);
        StorageUnit unit = StorageUnit.builder().facility(facility).build();
        User assigned = new User();
        assigned.setId(UUID.randomUUID());
        User caller = new User();
        caller.setId(UUID.randomUUID());
        Booking booking = Booking.builder().storageUnit(unit)
                .status(BookingStatus.ACTIVE).assignedCheckOutStaff(assigned).build();
        when(access.require("caller@test.com", facilityId)).thenReturn(caller);
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));

        AppException error = assertThrows(AppException.class,
                () -> operations.checkOut(bookingId, facilityId, "caller@test.com",
                        HandoverRequest.builder().unitCondition("Good")
                                .lockCondition("Working").build()));
        assertEquals(ErrorCode.HANDOVER_ASSIGNED_TO_ANOTHER_STAFF, error.getErrorCode());
    }

    @Test
    void managerCanAssignOnlyActiveStaffFromTheSameFacility() {
        UUID facilityId = UUID.randomUUID();
        UUID bookingId = UUID.randomUUID();
        UUID staffId = UUID.randomUUID();
        Facility facility = new Facility();
        facility.setId(facilityId);
        StorageUnit unit = StorageUnit.builder().facility(facility).build();
        User manager = User.builder().role(Role.builder().name("FACILITY_MANAGER").build()).build();
        User staff = User.builder().facility(facility)
                .role(Role.builder().name("STAFF").build()).isActive(true)
                .fullName("Ba").build();
        staff.setId(staffId);
        Booking booking = Booking.builder().status(BookingStatus.CONFIRMED)
                .storageUnit(unit).startDate(java.time.LocalDate.now()).build();
        booking.setId(bookingId);
        when(access.require("manager@test.com", facilityId)).thenReturn(manager);
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));
        when(users.findById(staffId)).thenReturn(Optional.of(staff));

        var assigned = operations.assignAppointment(bookingId, facilityId,
                "manager@test.com", "CHECK_IN", staffId);

        assertEquals(staffId, assigned.getAssignedStaffId());
        assertEquals(staff, booking.getAssignedCheckInStaff());
        verify(bookings).save(booking);
    }

    @Test
    void managerCannotAssignStaffFromAnotherFacility() {
        UUID facilityId = UUID.randomUUID();
        UUID bookingId = UUID.randomUUID();
        UUID staffId = UUID.randomUUID();
        Facility facility = new Facility();
        facility.setId(facilityId);
        Facility other = new Facility();
        other.setId(UUID.randomUUID());
        User manager = User.builder().role(Role.builder().name("FACILITY_MANAGER").build()).build();
        User staff = User.builder().facility(other)
                .role(Role.builder().name("STAFF").build()).isActive(true).build();
        Booking booking = Booking.builder().status(BookingStatus.CONFIRMED)
                .storageUnit(StorageUnit.builder().facility(facility).build()).build();
        when(access.require("manager@test.com", facilityId)).thenReturn(manager);
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));
        when(users.findById(staffId)).thenReturn(Optional.of(staff));

        AppException error = assertThrows(AppException.class,
                () -> operations.assignAppointment(bookingId, facilityId,
                        "manager@test.com", "CHECK_IN", staffId));
        assertEquals(ErrorCode.INVALID_REQUEST, error.getErrorCode());
    }
}
