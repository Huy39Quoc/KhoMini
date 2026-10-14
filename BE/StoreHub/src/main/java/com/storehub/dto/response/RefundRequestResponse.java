package com.storehub.dto.response;

import com.storehub.enums.RefundStatus;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

public record RefundRequestResponse(
        UUID id,
        UUID bookingId,
        String bookingCode,
        String originalTransactionId,
        String requestId,
        BigDecimal amount,
        RefundStatus status,
        String gatewayResponseCode,
        String gatewayTransactionStatus,
        LocalDateTime dueAt,
        boolean overdue,
        BigDecimal damageDeduction,
        String bankCode,
        String bankAccountNumber,
        String bankAccountName,
        String transferReference
) {
    public RefundRequestResponse(
            UUID id,
            UUID bookingId,
            String bookingCode,
            String originalTransactionId,
            String requestId,
            BigDecimal amount,
            RefundStatus status,
            String gatewayResponseCode,
            String gatewayTransactionStatus,
            LocalDateTime dueAt,
            boolean overdue
    ) {
        this(id, bookingId, bookingCode, originalTransactionId, requestId, amount, status,
                gatewayResponseCode, gatewayTransactionStatus, dueAt, overdue,
                BigDecimal.ZERO, null, null, null, null);
    }
}
