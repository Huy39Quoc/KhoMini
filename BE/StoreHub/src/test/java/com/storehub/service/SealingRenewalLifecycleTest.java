package com.storehub.service;

import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.*;
import com.storehub.scheduler.OverdueScheduler;
import com.storehub.service.impl.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import static com.storehub.common.PaymentNotes.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SealingRenewalLifecycleTest {
    @Mock BookingRepository bookings;
    @Mock PaymentRepository payments;
    @Mock RefundRequestRepository refunds;
    @Mock ActivityLogService logs;
    @Mock OverdueScheduler overdueScheduler;
    @Mock FacilityAccess access;
    @Mock FacilityRepository facilities;
    @InjectMocks CustomerStorageServiceImpl customer;
    @InjectMocks PaymentServiceImpl paymentService;
    @InjectMocks FacilityManagementServiceImpl manager;

    Booking overdue() {
        Facility facility = new Facility(); facility.setId(UUID.randomUUID());
        StorageUnit unit = StorageUnit.builder().facility(facility)
                .unitType(UnitType.builder().typeName("Small").build()).unitCode("A-1").build();
        Booking booking = Booking.builder().status(BookingStatus.ACTIVE).bookingCode("BK-SEAL")
                .storageUnit(unit).customer(new User()).endDate(LocalDate.now().minusDays(10))
                .rentalMonths(1).totalRentalFee(new BigDecimal("1000"))
                .overdueDetectedAt(LocalDateTime.now().minusDays(9))
                .sealingPendingAt(LocalDateTime.now().minusDays(3))
                .sealingApprovedAt(LocalDateTime.now().minusDays(2))
                .accessDisabledAt(LocalDateTime.now().minusDays(5))
                .overdueFeeAccrued(new BigDecimal("100")).build();
        booking.setId(UUID.randomUUID());
        return booking;
    }

    void reconcile(Booking booking) {
        ReflectionTestUtils.invokeMethod(customer, "reconcileOverdueState", booking);
    }

    @Test
    void paidExtensionClosesEpisodeImmediatelyAndPreservesOldApprovalInHistory() {
        Booking booking = overdue();
        LocalDateTime approval = booking.getSealingApprovedAt();
        booking.setPendingExtraMonths(1);
        booking.setPendingExtensionFee(new BigDecimal("1000"));
        Payment payment = Payment.builder().booking(booking).transactionId("EXT-1")
                .paymentType(PaymentType.EXTRA_CHARGE).note(RENTAL_EXTENSION)
                .amount(new BigDecimal("1000")).build();

        ReflectionTestUtils.invokeMethod(paymentService, "processPaymentConfirmation", payment, booking);

        assertEquals(PaymentStatus.PAID, payment.getStatus());
        assertNull(booking.getSealingApprovedAt());
        assertNull(booking.getSealingPendingAt());
        assertNull(booking.getAccessDisabledAt());
        assertNull(booking.getOverdueDetectedAt());
        assertEquals(BigDecimal.ZERO, booking.getOverdueFeeAccrued());
        verify(logs).record(eq(ActivityAction.OVERDUE_RESOLVED), eq("BOOKING"), eq(booking.getId()),
                anyString(), argThat(old -> approval.toString().equals(((Map<?, ?>) old).get("sealingApprovedAt"))), any());
    }

    @Test
    void unpaidLateFeeKeepsApprovalAndAccessRestriction() {
        Booking booking = overdue();
        booking.setEndDate(LocalDate.now().plusMonths(1));
        LocalDateTime approval = booking.getSealingApprovedAt();
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(booking.getId(),
                PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE, List.of(PaymentStatus.PENDING, PaymentStatus.FAILED)))
                .thenReturn(List.of(Payment.builder().amount(BigDecimal.TEN).build()));
        reconcile(booking);
        assertEquals(approval, booking.getSealingApprovedAt());
        assertNotNull(booking.getAccessDisabledAt());
        verifyNoInteractions(logs);
    }

    @Test
    void stillOverdueContractIsNotRestored() {
        Booking booking = overdue();
        reconcile(booking);
        assertNotNull(booking.getSealingApprovedAt());
        verifyNoInteractions(logs);
    }

    @Test
    void legacyApprovalWithoutOtherOverdueFlagsIsClearedOnce() {
        Booking booking = overdue();
        booking.setEndDate(LocalDate.now().plusMonths(1));
        booking.setOverdueDetectedAt(null);
        booking.setAccessDisabledAt(null);
        booking.setSealingPendingAt(null);
        reconcile(booking);
        reconcile(booking);
        assertNull(booking.getSealingApprovedAt());
        verify(logs, times(1)).record(eq(ActivityAction.OVERDUE_RESOLVED), anyString(), any(), anyString(), any(), any());
    }

    @Test
    void laterEpisodeRequiresNewApprovalAndRepeatedApprovalIsIdempotent() {
        Booking booking = overdue();
        booking.setEndDate(LocalDate.now().plusMonths(1));
        reconcile(booking);
        booking.setEndDate(LocalDate.now().minusDays(8));
        LocalDateTime pending = LocalDateTime.now().minusMinutes(1);
        booking.setOverdueDetectedAt(pending);
        booking.setSealingPendingAt(pending);
        UUID facilityId = booking.getStorageUnit().getFacility().getId();
        when(facilities.findById(facilityId)).thenReturn(Optional.of(booking.getStorageUnit().getFacility()));
        when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
        assertNull(booking.getSealingApprovedAt());
        assertTrue(manager.approveSealing(facilityId, booking.getId(), "manager@test.com").sealingApproved());
        LocalDateTime approved = booking.getSealingApprovedAt();
        manager.approveSealing(facilityId, booking.getId(), "manager@test.com");
        assertEquals(approved, booking.getSealingApprovedAt());
        assertFalse(approved.isBefore(pending));
        verify(logs, times(1)).record(eq(ActivityAction.OVERDUE_SEALING_APPROVED), anyString(), any(), anyString(), any(), any());
        verify(bookings, never()).findById(booking.getId());
    }

    @Test
    void renewedContractCannotBeApprovedUsingStalePendingFlag() {
        Booking booking = overdue();
        booking.setEndDate(LocalDate.now().plusMonths(1));
        UUID facilityId = booking.getStorageUnit().getFacility().getId();
        when(facilities.findById(facilityId)).thenReturn(Optional.of(booking.getStorageUnit().getFacility()));
        when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
        AppException error = assertThrows(AppException.class,
                () -> manager.approveSealing(facilityId, booking.getId(), "manager@test.com"));
        assertEquals(ErrorCode.UNIT_NOT_OVERDUE, error.getErrorCode());
        verifyNoInteractions(logs);
    }
}
