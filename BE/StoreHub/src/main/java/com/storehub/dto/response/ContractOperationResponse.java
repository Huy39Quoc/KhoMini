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
    private BigDecimal additionalFee;      // Phí phát sinh khi gia hạn
    private BigDecimal updatedTotalFee;     // Tổng tiền thuê mới sau gia hạn
    private LocalDateTime scheduledReturnTime; // Thời gian hẹn trả kho
    private String message;
}