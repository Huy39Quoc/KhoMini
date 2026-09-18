package com.storehub.dto.response;

import lombok.*;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SystemRevenueSummaryResponse {
    private BigDecimal totalRevenue;
    private BigDecimal depositRevenue;
    private BigDecimal rentalFeeRevenue;
    private BigDecimal extraChargeRevenue;
    private Long paymentCount;

    public SystemRevenueSummaryResponse(Object totalRevenue, Object depositRevenue, Object rentalFeeRevenue, Object extraChargeRevenue, Number paymentCount) {
        this.totalRevenue = toBigDecimal(totalRevenue);
        this.depositRevenue = toBigDecimal(depositRevenue);
        this.rentalFeeRevenue = toBigDecimal(rentalFeeRevenue);
        this.extraChargeRevenue = toBigDecimal(extraChargeRevenue);
        this.paymentCount = paymentCount != null ? paymentCount.longValue() : 0L;
    }

    private static BigDecimal toBigDecimal(Object value) {
        if (value == null) return BigDecimal.ZERO;
        if (value instanceof BigDecimal bd) return bd;
        if (value instanceof Number num) return BigDecimal.valueOf(num.doubleValue());
        return new BigDecimal(value.toString());
    }
}
