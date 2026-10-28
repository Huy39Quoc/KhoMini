package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FacilityPolicyCreateRequest {

    @NotNull(message = "Vui lòng chọn cơ sở")
    private java.util.UUID facilityId;

    @NotNull @DecimalMin(value = "0.0") @DecimalMax(value = "100.0")
    private Double depositPercentage;

    @NotNull @Min(0)
    private Integer renewalWindowDays;


    @NotNull @Min(0)
    private Integer cancellationFullRefundHours;

    @NotNull @Min(0)
    private Integer cancellationPartialRefundHours;

    @NotNull @DecimalMin(value = "0.0") @DecimalMax(value = "100.0")
    private Double cancellationPartialRefundPercent;

    @NotNull @Min(0)
    private Integer returnNoticeDays;

    @NotNull @Min(0)
    private Integer depositRefundSlaDays;

    @NotNull @DecimalMin(value = "0.0")
    private BigDecimal dailyLateFee;

    @NotNull @Min(0)
    private Integer overdueGraceDays;

    @NotNull @Min(0)
    private Integer overdueAccessDisableDays;

    @NotNull @Min(0)
    private Integer overdueSealingDays;

    @NotNull @Min(1)
    private Integer minimumRentalMonths;

    @Min(1)
    @Builder.Default
    private Integer maxAdvanceReservationDays = 14;

    @DecimalMin(value = "0.0")
    private BigDecimal managementFeePerMonth;
    @Min(0)
    private Integer longTermDiscountMinMonths;
    @DecimalMin(value = "0.0") @DecimalMax(value = "100.0")
    private Double longTermDiscountPercent;

    private String prohibitedItems;
    private String termsAndConditions;
    @Size(max = 30)
    @Pattern(regexp = "\\S+", message = "Phiên bản điều khoản không được trống hoặc chứa khoảng trắng")
    private String termsVersion;
}
