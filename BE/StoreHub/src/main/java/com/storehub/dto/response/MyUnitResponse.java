package com.storehub.dto.response;

import com.storehub.enums.BookingStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MyUnitResponse {
    private UUID bookingId;
    private String bookingCode;
    private String facilityName;
    private String facilityAddress;
    private String unitCode;
    private String unitTypeName;
    private String dimensions;
    private Double areaSqm;
    private LocalDate startDate;
    private LocalDate endDate;
    private Integer rentalMonths;
    private BookingStatus status;
    private BigDecimal totalRentalFee;
    private BigDecimal depositPaid;
    // Lombok sinh isActiveAccess(), Jackson serialize thành "activeAccess"
    private boolean activeAccess;
}