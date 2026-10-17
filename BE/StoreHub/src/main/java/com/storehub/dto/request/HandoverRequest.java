package com.storehub.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class HandoverRequest {

    @NotBlank(message = "Vui lòng chọn tình trạng ngăn kho")
    private String unitCondition;

    @NotBlank(message = "Vui lòng chọn tình trạng khóa")
    private String lockCondition;

    private String notes;

    @DecimalMin(value = "0.0", message = "Phí hư hại không được âm")
    private BigDecimal damageFee;

    private String damageReason;

    private List<String> photos;
}