package com.storehub.dto.response;

import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class PaymentResponse {

    private UUID id;
    private String transactionId;
    private UUID bookingId;
    private String bookingCode;
    private String customerName;
    private String customerEmail;
    private String facilityName;
    private String unitCode;
    private BigDecimal amount;
    private PaymentType paymentType;
    private PaymentStatus status;
    private com.storehub.enums.RefundStatus refundStatus;
    private String paymentMethod;
    private String note;
    private String paymentUrl;
    private String qrCodeUrl;
    private LocalDateTime paymentTime;
}
