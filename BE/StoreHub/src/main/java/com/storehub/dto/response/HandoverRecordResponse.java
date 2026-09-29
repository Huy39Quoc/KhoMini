package com.storehub.dto.response;

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
        LocalDateTime recordedAt
) {
}