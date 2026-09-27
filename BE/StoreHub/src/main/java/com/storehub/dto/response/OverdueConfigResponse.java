package com.storehub.dto.response;

import java.math.BigDecimal;

public record OverdueConfigResponse(
        int graceDays,
        BigDecimal dailyLateFee,
        int accessDisableDays,
        int sealingDays
) {
}