package com.storehub.dto.response;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
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
        String damageReason,
        List<String> photos
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
        this(id, bookingId, recordType, unitCondition, notes, staffId, staffName, recordedAt, null, null, null);
    }

    public HandoverRecordResponse(
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
        this(id, bookingId, recordType, unitCondition, notes, staffId, staffName, recordedAt, damageFee, damageReason, null);
    }
}