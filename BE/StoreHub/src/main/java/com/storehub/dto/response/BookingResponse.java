package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class BookingResponse {
    private UUID id;
    private String bookingCode;
    private UUID customerId;
    private UUID storageUnitId;
    private String unitCode;
    private LocalDate startDate;
    private LocalDate endDate;
    private Integer rentalMonths;
    private BigDecimal totalRentalFee;
    private BigDecimal depositPaid;
    private BookingStatus status;
    private LocalDateTime createdAt;
}
