package com.storehub.dto.response;

import lombok.*;
import java.math.BigDecimal;

@Data @Builder @NoArgsConstructor @AllArgsConstructor
public class DepositReconciliationResponse {
    @Builder.Default private BigDecimal openingBalance = BigDecimal.ZERO;
    @Builder.Default private BigDecimal received = BigDecimal.ZERO;
    @Builder.Default private BigDecimal refunded = BigDecimal.ZERO;
    @Builder.Default private BigDecimal retained = BigDecimal.ZERO;
    @Builder.Default private BigDecimal damageRetained = BigDecimal.ZERO;
    @Builder.Default private BigDecimal cancellationRetained = BigDecimal.ZERO;

    public BigDecimal getClosingBalance() {
        return openingBalance.add(received).subtract(refunded).subtract(retained);
    }

    public void add(DepositReconciliationResponse other) {
        openingBalance = openingBalance.add(other.openingBalance);
        received = received.add(other.received);
        refunded = refunded.add(other.refunded);
        retained = retained.add(other.retained);
        damageRetained = damageRetained.add(other.damageRetained);
        cancellationRetained = cancellationRetained.add(other.cancellationRetained);
    }
}
