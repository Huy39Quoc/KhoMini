package com.storehub.dto.response;

import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@AllArgsConstructor
@Builder
public class FacilityPolicyResponse {
    private java.time.LocalDateTime cancellationPolicyEffectiveAt;
    private UUID id;
    private UUID facilityId;
    private String facilityName;
    private Double depositPercentage;

    private Integer renewalWindowDays;

    private Integer cancellationFullRefundHours;
    private Integer cancellationPartialRefundHours;
    private Double cancellationPartialRefundPercent;

    private Integer returnNoticeDays;
    private Integer depositRefundSlaDays;

    private BigDecimal dailyLateFee;
    private Integer overdueGraceDays;
    private Integer overdueAccessDisableDays;
    private Integer overdueSealingDays;

    private Integer minimumRentalMonths;
    private Integer maxAdvanceReservationDays;
    private BigDecimal managementFeePerMonth;
    private Integer longTermDiscountMinMonths;
    private Double longTermDiscountPercent;
    private String prohibitedItems;
    private String termsAndConditions;
    private String termsVersion;
}
