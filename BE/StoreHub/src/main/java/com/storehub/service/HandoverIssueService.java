package com.storehub.service;

import com.storehub.dto.request.HandoverIssueResolutionRequest;
import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.exception.*;
import com.storehub.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import java.time.*;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@lombok.extern.slf4j.Slf4j
public class HandoverIssueService {
    private final BookingRepository bookings;
    private final StorageUnitRepository units;
    private final FacilityAccess access;
    private final PaymentService payments;
    private final WaitlistService waitlist;
    private final ActivityLogService logs;
    private final FacilityPolicyService policies;

    @Transactional
    public void resolve(UUID facilityId, UUID bookingId, String managerEmail, HandoverIssueResolutionRequest request) {
        User manager = access.require(managerEmail, facilityId);
        if (manager.getRole() == null || !"FACILITY_MANAGER".equals(manager.getRole().getName())) {
            throw new AppException(ErrorCode.FORBIDDEN);
        }
        Booking booking = bookings.lockById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));
        if (booking.getStorageUnit() == null || booking.getStorageUnit().getFacility() == null
                || !facilityId.equals(booking.getStorageUnit().getFacility().getId())) {
            throw new AppException(ErrorCode.BOOKING_NOT_FOUND);
        }
        if (booking.getHandoverIssueReportedAt() == null || booking.getHandoverTime() != null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        // A repeated cancellation must not queue another refund.
        if (booking.getStatus() == BookingStatus.CANCELLED
                && booking.getHandoverIssueStatus() == HandoverIssueStatus.CANCELLED
                && request.getAction() == HandoverIssueResolutionRequest.Action.CANCEL_REFUND) return;
        if (booking.getStatus() != BookingStatus.CONFIRMED || request.getAction() == null
                || request.getNotes() == null || request.getNotes().isBlank()) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Asia/Ho_Chi_Minh"));
        StorageUnit oldUnit = units.lockById(booking.getStorageUnit().getId())
                .orElseThrow(() -> new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND));
        if (oldUnit.getStatus() != UnitStatus.RESERVED && oldUnit.getStatus() != UnitStatus.UNDER_MAINTENANCE) {
            throw new AppException(ErrorCode.UNIT_UNAVAILABLE);
        }
        if (bookings.existsByStorageUnit_IdAndStatusInAndIdNot(oldUnit.getId(),
                java.util.List.of(BookingStatus.PENDING_PAYMENT, BookingStatus.CONFIRMED, BookingStatus.ACTIVE), bookingId)) {
            throw new AppException(ErrorCode.UNIT_UNAVAILABLE);
        }
        if (request.getAction() == HandoverIssueResolutionRequest.Action.CANCEL_REFUND) {
            payments.refundForFacilityFailure(booking);
            booking.setStatus(BookingStatus.CANCELLED);
            booking.setHandoverIssueStatus(HandoverIssueStatus.CANCELLED);
            if (oldUnit.getStatus() == UnitStatus.RESERVED) {
                oldUnit.setStatus(UnitStatus.AVAILABLE);
                units.save(oldUnit);
                waitlist.notifyNextInWaitlist(facilityId, oldUnit.getUnitType().getId());
            }
        } else {
            if (!Boolean.TRUE.equals(request.getCustomerAgreed()) || request.getScheduledCheckInTime() == null) {
                throw new AppException(ErrorCode.HANDOVER_ISSUE_CONSENT_REQUIRED);
            }
            if (booking.getHandoverIssueDueAt() == null || !booking.getHandoverIssueDueAt().isAfter(now)) {
                throw new AppException(ErrorCode.HANDOVER_ISSUE_RESOLUTION_REQUIRED);
            }
            LocalDateTime appointment = request.getScheduledCheckInTime();
            Facility facility = oldUnit.getFacility();
            if (!appointment.isAfter(now) || appointment.toLocalDate().isBefore(booking.getStartDate())
                    || appointment.toLocalDate().isAfter(now.toLocalDate().plusDays(policies.getMaxAdvanceReservationDays(facilityId)))
                    || facility.getOpenTime() == null || facility.getCloseTime() == null
                    || appointment.toLocalTime().isBefore(facility.getOpenTime())
                    || !appointment.toLocalTime().isBefore(facility.getCloseTime())
                    || facility.getStatus() != FacilityStatus.ACTIVE) {
                throw new AppException(ErrorCode.INVALID_REQUEST);
            }
            StorageUnit target = oldUnit;
            if (request.getAction() == HandoverIssueResolutionRequest.Action.REPLACE_UNIT) {
                if (request.getReplacementUnitId() == null || request.getReplacementUnitId().equals(oldUnit.getId())) {
                    throw new AppException(ErrorCode.UNIT_UNAVAILABLE);
                }
                target = units.lockById(request.getReplacementUnitId())
                        .orElseThrow(() -> new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND));
                if (target.getFacility() == null || !facilityId.equals(target.getFacility().getId())
                        || target.getUnitType() == null || oldUnit.getUnitType() == null
                        || !target.getUnitType().getId().equals(oldUnit.getUnitType().getId())
                        || target.getStatus() != UnitStatus.AVAILABLE) {
                    throw new AppException(ErrorCode.UNIT_UNAVAILABLE);
                }
                target.setStatus(UnitStatus.RESERVED);
                units.save(target);
                if (oldUnit.getStatus() == UnitStatus.RESERVED) {
                    oldUnit.setStatus(UnitStatus.AVAILABLE);
                    units.save(oldUnit);
                    waitlist.notifyNextInWaitlist(facilityId, oldUnit.getUnitType().getId());
                }
                booking.setStorageUnit(target);
            }
            // The customer receives the full agreed number of months, with no
            // extra charge or price recalculation for delays caused by the facility.
            booking.setStartDate(appointment.toLocalDate());
            booking.setEndDate(appointment.toLocalDate().plusMonths(booking.getRentalMonths()));
            booking.setScheduledCheckInTime(appointment);
            booking.setUnitAssignmentConfirmed(true);
            booking.setHandoverIssueCustomerAgreedAt(now);
            booking.setHandoverIssueStatus(HandoverIssueStatus.ARRANGED);
            booking.setHandoverIssueDueAt(appointment.plusHours(24));
        }
        booking.setAssignedCheckInStaff(null); // New time requires explicit assignment.
        booking.setHandoverIssueResolvedBy(manager.getId());
        String actionLabel = switch (request.getAction()) {
            case REPLACE_UNIT -> "Đổi ngăn";
            case RESCHEDULE -> "Đổi lịch";
            case CANCEL_REFUND -> "Hủy và yêu cầu hoàn toàn bộ";
        };
        booking.setHandoverIssueResolutionNote(actionLabel + ": " + request.getNotes().trim());
        bookings.save(booking);
        String note = booking.getHandoverIssueResolutionNote();
        afterCommit(() -> {
            try { logs.recordSystem(ActivityAction.HANDOVER_ISSUE_UPDATE, "BOOKING", bookingId,
                    "Facility handover issue: " + note.substring(0, Math.min(400, note.length()))); }
            catch (RuntimeException ex) { log.error("Issue resolution audit failed for {}", bookingId, ex); }
        });
    }

    private void afterCommit(Runnable action) {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override public void afterCommit() { action.run(); }
            });
        } else action.run();
    }
}
