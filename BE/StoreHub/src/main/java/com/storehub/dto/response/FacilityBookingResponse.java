package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;

import java.time.LocalDate;
import java.util.UUID;

public record FacilityBookingResponse(
        UUID bookingId,
        String bookingCode,
        String customerName,
        String customerEmail,
        LocalDate startDate,
        LocalDate endDate,
        UUID storageUnitId,
        String unitCode,
        UUID unitTypeId,
        String unitType,
        BookingStatus status
) {
}