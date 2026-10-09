package com.storehub.dto.request;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class RefundGatewayMetadataRequest {
    @NotNull @Pattern(regexp = "[0-9]{14}")
    private String transactionDate;

    @Pattern(regexp = "[0-9]{1,15}")
    private String transactionNo;

    @NotNull @Positive
    private BigDecimal originalAmount;
}
