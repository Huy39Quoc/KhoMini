package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

/** Hợp đồng thuê (booking CONFIRMED / ACTIVE) để Facility Manager theo dõi. */
public record FacilityContractResponse(
        UUID bookingId,
        String bookingCode,
        String customerName,
        String customerEmail,
        String unitCode,
        String unitType,
        LocalDate startDate,
        LocalDate endDate,
        Integer rentalMonths,
        BookingStatus status,
        BigDecimal depositPaid,
        BigDecimal totalRentalFee,
        LocalDateTime returnTime,
        boolean overdue,
        long overdueDays,
        BigDecimal overdueFeeAccrued,
        boolean accessDisabled,
        boolean sealingPending,
        BigDecimal pendingExtensionFee,
        boolean sealingApproved
) {}
