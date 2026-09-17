package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FacilityPolicyCreateRequest {

    @NotNull(message = "Facility id is required")
    private UUID facilityId;

    @NotNull(message = "Deposit percentage is required")
    @DecimalMin(value = "0.0", message = "Deposit percentage must not be negative")
    @DecimalMax(value = "100.0", message = "Deposit percentage must not exceed 100")
    private Double depositPercentage;

    @NotNull(message = "Daily late fee is required")
    @DecimalMin(value = "0.0", message = "Daily late fee must not be negative")
    private BigDecimal dailyLateFee;

    @NotNull(message = "Cancellation refund days is required")
    @Min(value = 0, message = "Cancellation refund days must not be negative")
    private Integer cancellationRefundDays;
}
