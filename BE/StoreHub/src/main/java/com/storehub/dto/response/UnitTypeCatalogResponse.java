package com.storehub.dto.response;

import lombok.*;
import java.math.BigDecimal;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UnitTypeCatalogResponse {
    private UUID id;
    private String typeName;
    private String dimensions;
    private Double areaSqm;
    private BigDecimal basePricePerMonth;
    private BigDecimal depositAmount;
    private Long availableUnitsCount;
}