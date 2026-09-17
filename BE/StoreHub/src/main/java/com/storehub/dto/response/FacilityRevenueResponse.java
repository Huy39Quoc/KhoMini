package com.storehub.dto.response;

import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@AllArgsConstructor
@Builder
public class FacilityRevenueResponse {
    private UUID facilityId;
    private String facilityName;
    private BigDecimal totalRevenue;
    private BigDecimal depositRevenue;
    private BigDecimal rentalFeeRevenue;
    private BigDecimal extraChargeRevenue;
    private long paymentCount;
}
