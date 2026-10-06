package com.storehub.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdateUnitTypePriceRequest {

    @NotNull(message = "Base price per month is required")
    @DecimalMin(value = "0.01", message = "Base price must be greater than 0")
    private BigDecimal basePricePerMonth;

    @NotNull(message = "Deposit amount is required")
    @DecimalMin(value = "0.00", message = "Deposit amount must not be negative")
    private BigDecimal depositAmount;
}
