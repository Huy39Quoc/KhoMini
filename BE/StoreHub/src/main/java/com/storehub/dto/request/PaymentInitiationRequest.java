package com.storehub.dto.request;

import com.storehub.enums.PaymentType;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.UUID;

@Data
public class PaymentInitiationRequest {

    @NotNull(message = "Vui lòng chọn đơn thuê")
    private UUID bookingId;

    @NotNull(message = "Vui lòng chọn loại thanh toán")
    private PaymentType paymentType;

    private String paymentMethod;
}
