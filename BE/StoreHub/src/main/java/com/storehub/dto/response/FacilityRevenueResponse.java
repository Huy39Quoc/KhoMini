package com.storehub.dto.response;

import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FacilityRevenueResponse {
    private UUID facilityId;
    private String facilityName;
    private BigDecimal totalRevenue;
    private BigDecimal depositRevenue;
    private BigDecimal rentalFeeRevenue;
    private BigDecimal extraChargeRevenue;
    private Long paymentCount;

    public FacilityRevenueResponse(UUID facilityId, String facilityName, Object totalRevenue, Object depositRevenue, Object rentalFeeRevenue, Object extraChargeRevenue, Number paymentCount) {
        this.facilityId = facilityId;
        this.facilityName = facilityName;
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
