package com.storehub.dto.response;

import com.storehub.enums.RentalFeeType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FeeItemResponse {

    private RentalFeeType feeType;
    private String name;
    private BigDecimal unitPrice;
    private Integer quantity;
    private BigDecimal totalAmount;
    private String note;
}