package com.storehub.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RentalQuoteResponse {

    private UUID unitTypeId;
    private String unitTypeName;
    private String dimensions;
    private Double areaSqm;
    private UUID storageUnitId;
    private String unitCode;
    private UUID facilityId;
    private String facilityName;

    private LocalDate startDate;
    private LocalDate endDate;
    private Integer rentalMonths;

    // Số tiền đã làm tròn theo đơn vị VNĐ (scale = 0)
    private BigDecimal basePricePerMonth;
    private BigDecimal totalRentalFee;
    private BigDecimal depositAmount;
    private BigDecimal totalExtraFees;
    private BigDecimal initialPaymentAmount;

    private List<FeeItemResponse> breakdown;
    private LocalDateTime quotedAt;
}