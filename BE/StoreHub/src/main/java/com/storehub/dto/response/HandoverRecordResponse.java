package com.storehub.dto.response;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

public record HandoverRecordResponse(
        UUID id,
        UUID bookingId,
        String recordType,
        String unitCondition,
        String notes,
        UUID staffId,
        String staffName,
        LocalDateTime recordedAt,
        BigDecimal damageFee,
        String damageReason
) {
    public HandoverRecordResponse(
            UUID id,
            UUID bookingId,
            String recordType,
            String unitCondition,
            String notes,
            UUID staffId,
            String staffName,
            LocalDateTime recordedAt
    ) {
        this(id, bookingId, recordType, unitCondition, notes, staffId, staffName, recordedAt, null, null);
    }
}