package com.storehub.dto.response;

import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@AllArgsConstructor
@Builder
public class FacilityPolicyResponse {
    private UUID id;
    private UUID facilityId;
    private String facilityName;
    private Double depositPercentage;
    private BigDecimal dailyLateFee;
    private Integer cancellationRefundDays;
}
