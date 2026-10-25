package com.storehub.service;

import com.storehub.dto.request.HandoverIssueResolutionRequest;
import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.exception.*;
import com.storehub.repository.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HandoverIssueServiceTest {
    @Mock BookingRepository bookings;
    @Mock StorageUnitRepository units;
    @Mock FacilityAccess access;
    @Mock PaymentService payments;
    @Mock WaitlistService waitlist;
    @Mock ActivityLogService logs;
    @Mock EmailService email;
    @Mock FacilityPolicyService policies;
    @InjectMocks HandoverIssueService service;
    Facility facility;
    StorageUnit oldUnit;
    Booking booking;
    User manager;
    HandoverIssueResolutionRequest request;
    LocalDateTime tomorrow;

    @BeforeEach void setup() {
        tomorrow = LocalDate.now().plusDays(1).atTime(9, 0);
        facility = Facility.builder().status(FacilityStatus.ACTIVE).openTime(LocalTime.of(8, 0))
                .closeTime(LocalTime.of(20, 0)).build(); facility.setId(UUID.randomUUID());
        UnitType type = new UnitType(); type.setId(UUID.randomUUID());
        oldUnit = StorageUnit.builder().facility(facility).unitType(type).status(UnitStatus.UNDER_MAINTENANCE).build();
        oldUnit.setId(UUID.randomUUID());
        manager = User.builder().role(Role.builder().name("FACILITY_MANAGER").build()).build(); manager.setId(UUID.randomUUID());
        booking = Booking.builder().bookingCode("BK-ISSUE").status(BookingStatus.CONFIRMED).storageUnit(oldUnit)
                .customer(User.builder().email("customer@test.com").build()).rentalMonths(2)
                .startDate(LocalDate.now().minusDays(10)).endDate(LocalDate.now().plusDays(50))
                .totalRentalFee(new java.math.BigDecimal("1000"))
                .handoverIssueStatus(HandoverIssueStatus.OPEN).handoverIssueReportedAt(LocalDateTime.now())
                .handoverIssueDueAt(LocalDateTime.now().plusHours(48)).build(); booking.setId(UUID.randomUUID());
        request = new HandoverIssueResolutionRequest();
        request.setAction(HandoverIssueResolutionRequest.Action.REPLACE_UNIT);
        request.setScheduledCheckInTime(tomorrow); request.setNotes("Khách đồng ý qua điện thoại"); request.setCustomerAgreed(true);
        when(access.require("manager@test.com", facility.getId())).thenReturn(manager);
        lenient().when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
    }

    void prepareUnit() { when(units.lockById(oldUnit.getId())).thenReturn(Optional.of(oldUnit)); }
    void resolve() { service.resolve(facility.getId(), booking.getId(), "manager@test.com", request); }

    @Test void replacementRequiresRecordedCustomerAgreement() {
        prepareUnit(); request.setCustomerAgreed(false);
        assertEquals(ErrorCode.HANDOVER_ISSUE_CONSENT_REQUIRED, assertThrows(AppException.class, this::resolve).getErrorCode());
        verify(bookings, never()).save(any()); verifyNoInteractions(payments);
    }

    @Test void replacementPreservesBrokenUnitAndRestoresFullPaidRentalPeriodWithoutExtraCharge() {
        prepareUnit(); when(policies.getMaxAdvanceReservationDays(facility.getId())).thenReturn(14);
        StorageUnit replacement = StorageUnit.builder().facility(facility).unitType(oldUnit.getUnitType())
                .status(UnitStatus.AVAILABLE).build(); replacement.setId(UUID.randomUUID());
        request.setReplacementUnitId(replacement.getId());
        when(units.lockById(replacement.getId())).thenReturn(Optional.of(replacement));
        resolve();
        assertSame(replacement, booking.getStorageUnit());
        assertEquals(UnitStatus.RESERVED, replacement.getStatus());
        assertEquals(UnitStatus.UNDER_MAINTENANCE, oldUnit.getStatus());
        assertEquals(tomorrow.toLocalDate(), booking.getStartDate());
        assertEquals(tomorrow.toLocalDate().plusMonths(2), booking.getEndDate());
        assertEquals(tomorrow.plusHours(24), booking.getHandoverIssueDueAt());
        assertEquals(HandoverIssueStatus.ARRANGED, booking.getHandoverIssueStatus());
        assertNotNull(booking.getHandoverIssueCustomerAgreedAt());
        assertEquals(manager.getId(), booking.getHandoverIssueResolvedBy());
        assertEquals(new java.math.BigDecimal("1000"), booking.getTotalRentalFee());
        assertNull(booking.getAssignedCheckInStaff());
        verifyNoInteractions(payments, waitlist);
    }

    @Test void cancellationQueuesFullRefundOnceWithoutOpeningBrokenUnitForSale() {
        prepareUnit(); request.setAction(HandoverIssueResolutionRequest.Action.CANCEL_REFUND);
        request.setCustomerAgreed(false);
        resolve(); resolve();
        assertEquals(BookingStatus.CANCELLED, booking.getStatus());
        assertEquals(HandoverIssueStatus.CANCELLED, booking.getHandoverIssueStatus());
        assertEquals(UnitStatus.UNDER_MAINTENANCE, oldUnit.getStatus());
        verify(payments).refundForFacilityFailure(booking);
        verify(payments, never()).refundOnCancellation(any()); verifyNoInteractions(waitlist);
    }

    @Test void reschedulePreservesMaintenanceUntilTheUnitIsActuallyRepaired() {
        prepareUnit(); when(policies.getMaxAdvanceReservationDays(facility.getId())).thenReturn(14);
        request.setAction(HandoverIssueResolutionRequest.Action.RESCHEDULE);
        resolve();
        assertEquals(UnitStatus.UNDER_MAINTENANCE, oldUnit.getStatus());
        assertTrue(booking.getUnitAssignmentConfirmed());
        assertEquals(HandoverIssueStatus.ARRANGED, booking.getHandoverIssueStatus());
    }

    @Test void staffCannotResolveOrCancelCustomerBookings() {
        manager.setRole(Role.builder().name("STAFF").build());
        assertEquals(ErrorCode.FORBIDDEN, assertThrows(AppException.class, this::resolve).getErrorCode());
        verifyNoInteractions(bookings, payments, units);
    }

    @Test void anotherFacilityCannotResolveTheIssue() {
        booking.getStorageUnit().setFacility(Facility.builder().build());
        assertEquals(ErrorCode.BOOKING_NOT_FOUND, assertThrows(AppException.class, this::resolve).getErrorCode());
        verifyNoInteractions(units, payments);
    }

    @Test void expiredIssueCannotBeExtendedAgainInsteadOfRefunding() {
        prepareUnit(); booking.setHandoverIssueDueAt(LocalDateTime.now().minusHours(1));
        assertEquals(ErrorCode.HANDOVER_ISSUE_RESOLUTION_REQUIRED, assertThrows(AppException.class, this::resolve).getErrorCode());
        verifyNoInteractions(payments); verify(bookings, never()).save(any());
    }
}
