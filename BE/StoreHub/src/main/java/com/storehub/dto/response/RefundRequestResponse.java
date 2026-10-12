package com.storehub.dto.response;

import com.storehub.enums.RefundStatus;
import java.math.BigDecimal;
import java.util.UUID;

public record RefundRequestResponse(UUID id, UUID bookingId, String bookingCode,
                                    String originalTransactionId, String requestId,
                                    BigDecimal amount, RefundStatus status,
                                    String gatewayResponseCode, String gatewayTransactionStatus) {}
