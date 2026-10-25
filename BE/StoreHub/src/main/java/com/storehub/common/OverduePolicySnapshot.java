package com.storehub.common;

import com.storehub.dto.response.OverdueConfigResponse;
import com.storehub.entity.Booking;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;

/** Never fall back to mutable facility policy when charging an existing contract. */
public final class OverduePolicySnapshot {
    private OverduePolicySnapshot() {}

    public static OverdueConfigResponse read(Booking booking) {
        if (booking.getOverdueDailyLateFee() == null || booking.getOverdueDailyLateFee().signum() < 0
                || booking.getOverdueGraceDays() == null || booking.getOverdueGraceDays() < 0
                || booking.getOverdueAccessDisableDays() == null || booking.getOverdueAccessDisableDays() < 0
                || booking.getOverdueSealingDays() == null || booking.getOverdueSealingDays() < 0) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        return new OverdueConfigResponse(booking.getOverdueGraceDays(), booking.getOverdueDailyLateFee(),
                booking.getOverdueAccessDisableDays(), booking.getOverdueSealingDays());
    }
}
