package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class PaymentConfirmationRequest {

    @NotBlank(message = "Transaction ID is required")
    private String transactionId;
}
