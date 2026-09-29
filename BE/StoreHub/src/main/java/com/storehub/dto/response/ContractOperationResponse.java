package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ContractOperationResponse {
    private UUID bookingId;
    private String bookingCode;
    private BookingStatus status;
    private LocalDate oldEndDate;
    private LocalDate newEndDate;
    private Integer totalRentalMonths;
    private BigDecimal additionalFee;
    private BigDecimal updatedTotalFee;
    private LocalDateTime scheduledReturnTime;
    private String message;
    private boolean paymentRequired;
    private String transactionId;
    private String qrCodeUrl;
}