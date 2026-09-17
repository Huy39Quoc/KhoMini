package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FacilityPolicyUpdateRequest {

    @DecimalMin(value = "0.0", message = "Deposit percentage must not be negative")
    @DecimalMax(value = "100.0", message = "Deposit percentage must not exceed 100")
    private Double depositPercentage;

    @DecimalMin(value = "0.0", message = "Daily late fee must not be negative")
    private BigDecimal dailyLateFee;

    @Min(value = 0, message = "Cancellation refund days must not be negative")
    private Integer cancellationRefundDays;
}
