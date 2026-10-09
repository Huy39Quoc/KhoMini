package com.storehub.service;

import com.storehub.dto.request.HandoverRequest;
import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.FacilityAccess;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.HandoverRecordRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.service.impl.FacilityOperationsServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FacilityOperationsReturnScheduleTest {
    @Mock BookingRepository bookings;
    @Mock HandoverRecordRepository records;
    @Mock StorageUnitRepository units;
    @Mock FacilityAccess access;
    @Mock PaymentService payments;
    @Mock WaitlistService waitlist;
    @Mock org.springframework.security.crypto.password.PasswordEncoder encoder;
    @Mock ActivityLogService logs;
    @InjectMocks FacilityOperationsServiceImpl operations;

    @Test
    void completedCheckoutPreservesTheOriginalAppointment() {
        UUID facilityId = UUID.randomUUID();
        UUID bookingId = UUID.randomUUID();
        UUID unitId = UUID.randomUUID();
        Facility facility = new Facility();
        facility.setId(facilityId);
        StorageUnit unit = StorageUnit.builder()
                .facility(facility).status(UnitStatus.OCCUPIED).build();
        unit.setId(unitId);
        LocalDateTime appointment = LocalDateTime.now().minusMinutes(5);
        Booking booking = Booking.builder()
                .storageUnit(unit).status(BookingStatus.ACTIVE)
                .scheduledReturnTime(appointment).build();
        booking.setId(bookingId);
        User staff = User.builder().fullName("Staff").build();
        staff.setId(UUID.randomUUID());
        when(access.require("staff@test.com", facilityId)).thenReturn(staff);
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));
        when(units.lockById(unitId)).thenReturn(Optional.of(unit));
        when(payments.refundDepositOnReturn(booking)).thenReturn(BigDecimal.ZERO);

        operations.checkOut(bookingId, facilityId, "staff@test.com",
                HandoverRequest.builder().unitCondition("Good")
                        .lockCondition("Working").build());

        assertEquals(appointment, booking.getScheduledReturnTime());
        assertEquals(BookingStatus.COMPLETED, booking.getStatus());
        assertEquals(UnitStatus.UNDER_MAINTENANCE, unit.getStatus());
        assertTrue(booking.getReturnTime().isAfter(appointment));
    }

    @Test
    void expiredConfirmedBookingCannotBeCheckedIn() {
        UUID facilityId = UUID.randomUUID();
        UUID bookingId = UUID.randomUUID();
        Facility facility = new Facility();
        facility.setId(facilityId);
        StorageUnit unit = StorageUnit.builder()
                .facility(facility).status(UnitStatus.RESERVED).build();
        Booking booking = Booking.builder().storageUnit(unit)
                .status(BookingStatus.CONFIRMED)
                .startDate(LocalDate.now().minusMonths(1))
                .endDate(LocalDate.now()).build();
        when(access.require("staff@test.com", facilityId)).thenReturn(new User());
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));

        AppException exception = assertThrows(AppException.class,
                () -> operations.checkIn(bookingId, facilityId, "staff@test.com",
                        HandoverRequest.builder().unitCondition("Good")
                                .lockCondition("Working").build()));

        assertEquals(ErrorCode.CHECKIN_RENTAL_ENDED, exception.getErrorCode());
        verify(records, never()).save(any());
    }
}
