package com.storehub.dto.request;

import com.storehub.enums.PaymentType;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class PaymentInitiationRequest {

    @NotNull(message = "Booking ID is required")
    private UUID bookingId;

    @NotNull(message = "Payment type is required")
    private PaymentType paymentType;

    private String paymentMethod;
}
