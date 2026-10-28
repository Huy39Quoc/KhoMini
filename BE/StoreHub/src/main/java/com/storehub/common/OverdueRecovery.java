package com.storehub.common;

import com.storehub.entity.Booking;
import com.storehub.enums.ActivityAction;
import com.storehub.enums.BookingStatus;
import com.storehub.service.ActivityLogService;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;

/** Called only after outstanding late fees have been checked by the caller. */
public final class OverdueRecovery {
    private OverdueRecovery() {}

    public static boolean restore(Booking booking, ActivityLogService logs) {
        if (booking.getStatus() != BookingStatus.ACTIVE || booking.getEndDate() == null
                || booking.getEndDate().isBefore(LocalDate.now())
                || (booking.getOverdueDetectedAt() == null && booking.getSealingPendingAt() == null
                    && booking.getSealingApprovedAt() == null && booking.getAccessDisabledAt() == null)) {
            return false;
        }
        // Keep the previous decision and episode timestamps in the activity history.
        Map<String, String> previous = Map.of(
                "overdueDetectedAt", String.valueOf(booking.getOverdueDetectedAt()),
                "sealingPendingAt", String.valueOf(booking.getSealingPendingAt()),
                "sealingApprovedAt", String.valueOf(booking.getSealingApprovedAt()),
                "accessDisabledAt", String.valueOf(booking.getAccessDisabledAt()));
        booking.setOverdueDetectedAt(null);
        booking.setOverdueFeeAccrued(BigDecimal.ZERO);
        booking.setSealingPendingAt(null);
        booking.setSealingApprovedAt(null);
        booking.setAccessDisabledAt(null);
        logs.record(ActivityAction.OVERDUE_RESOLVED, "BOOKING", booking.getId(),
                "Overdue episode closed after renewal for booking " + booking.getBookingCode()
                        + "; previous sealing approval is no longer effective",
                previous, Map.of("endDate", booking.getEndDate().toString()));
        return true;
    }
}
