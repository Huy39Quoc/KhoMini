package com.storehub.scheduler;

import com.storehub.entity.Booking;
import com.storehub.entity.StorageUnit;
import com.storehub.enums.ActivityAction;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.PaymentService;
import com.storehub.service.WaitlistService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

/** Close paid reservations that were never handed over before their rental ended. */
@Component
@RequiredArgsConstructor
@Slf4j
public class UnclaimedBookingExpiryScheduler {
    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    private final BookingRepository bookings;
    private final StorageUnitRepository units;
    private final PaymentService payments;
    private final WaitlistService waitlist;
    private final ActivityLogService activityLog;
    private final PlatformTransactionManager transactionManager;

    @Scheduled(fixedDelay = 60_000, initialDelay = 60_000)
    public void expireUnclaimedBookings() {
        LocalDate today = LocalDate.now(BUSINESS_ZONE);
        LocalDateTime now = LocalDateTime.now(BUSINESS_ZONE);
        java.util.Set<UUID> candidates = new java.util.LinkedHashSet<>(bookings.findExpiredUnclaimedBookingIds(today));
        candidates.addAll(bookings.findOverdueHandoverIssueIds(now));
        for (UUID id : candidates) {
            try {
                // Each booking commits independently. One broken financial record
                // must not prevent other expired reservations from being released.
                ExpiredBooking expired = new TransactionTemplate(transactionManager)
                        .execute(status -> expire(id, today, now));
                if (expired != null) {
                    // recordSystem uses a separate transaction: log success only
                    // after cancellation and its financial settlement have committed.
                    try {
                        activityLog.recordSystem(ActivityAction.RESERVATION_EXPIRE, "BOOKING", id,
                                "Paid reservation " + expired.bookingCode()
                                        + " expired without handover at rental end " + expired.endDate()
                                        + "; settlement: " + expired.settlement());
                    } catch (RuntimeException exception) {
                        log.error("Unclaimed booking {} expired but its audit log failed", id, exception);
                    }
                    if (expired.facilityId() != null && expired.unitTypeId() != null) {
                        waitlist.notifyNextInWaitlist(expired.facilityId(), expired.unitTypeId());
                    }
                }
            } catch (RuntimeException exception) {
                log.error("Could not expire unclaimed booking {}; retry on the next run", id, exception);
            }
        }
    }

    private ExpiredBooking expire(UUID id, LocalDate today, LocalDateTime now) {
        // Check-in, customer cancellation and payment callbacks use this same lock.
        Booking booking = bookings.lockById(id).orElse(null);
        if (booking == null || booking.getStatus() != BookingStatus.CONFIRMED
                || booking.getEndDate() == null
                || booking.getHandoverTime() != null || booking.getHandedOverByStaffId() != null) {
            return null;
        }
        boolean facilityFailure = booking.getHandoverIssueReportedAt() != null;
        if (facilityFailure) {
            // Never turn a facility failure into a customer no-show, even after
            // the original end date. Wait for its separate resolution deadline.
            if (booking.getHandoverIssueDueAt() == null || booking.getHandoverIssueDueAt().isAfter(now)) return null;
        } else if (booking.getEndDate().isAfter(today)) return null;
        if (booking.getStorageUnit() == null) {
            throw new IllegalStateException("Unclaimed booking has no storage unit");
        }
        StorageUnit unit = units.lockById(booking.getStorageUnit().getId())
                .orElseThrow(() -> new IllegalStateException("Unclaimed booking unit is missing"));
        if (unit.getStatus() != UnitStatus.RESERVED && unit.getStatus() != UnitStatus.UNDER_MAINTENANCE) {
            // Inconsistent occupancy requires inspection, never release an occupied unit.
            throw new IllegalStateException("Unclaimed booking has unexpected unit status " + unit.getStatus());
        }
        if (bookings.existsByStorageUnit_IdAndStatusInAndIdNot(unit.getId(),
                List.of(BookingStatus.PENDING_PAYMENT, BookingStatus.CONFIRMED, BookingStatus.ACTIVE), id)) {
            throw new IllegalStateException("Unclaimed booking unit is also held by another open booking");
        }

        // Reuse the contract's frozen cancellation policy and existing refund /
        // deposit-retention ledger. Do not fabricate a completed bank refund.
        if (facilityFailure) {
            payments.refundForFacilityFailure(booking);
            booking.setHandoverIssueStatus(com.storehub.enums.HandoverIssueStatus.CANCELLED);
            booking.setHandoverIssueResolutionNote("Tự động hủy do quá hạn xử lý lỗi cơ sở; hoàn toàn bộ khoản đã thu");
        } else payments.refundOnCancellation(booking);
        booking.setStatus(BookingStatus.CANCELLED);
        booking.setAssignedCheckInStaff(null);
        bookings.save(booking);

        // A failed handover may have left the unit in maintenance. Keep that state.
        if (unit.getStatus() == UnitStatus.RESERVED) {
            unit.setStatus(UnitStatus.AVAILABLE);
            units.save(unit);
            if (unit.getFacility() != null && unit.getUnitType() != null) {
                return new ExpiredBooking(booking.getBookingCode(), booking.getEndDate(),
                        unit.getFacility().getId(), unit.getUnitType().getId(),
                        facilityFailure ? "full facility-failure refund requested" : "contract cancellation policy");
            }
        }
        return new ExpiredBooking(booking.getBookingCode(), booking.getEndDate(), null, null,
                facilityFailure ? "full facility-failure refund requested" : "contract cancellation policy");
    }

    private record ExpiredBooking(String bookingCode, LocalDate endDate, UUID facilityId, UUID unitTypeId, String settlement) {}
}
