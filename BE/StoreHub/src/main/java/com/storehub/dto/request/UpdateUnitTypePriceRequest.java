package com.storehub.dto.request;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdateUnitTypePriceRequest {

    @NotNull(message = "Vui lòng nhập giá thuê theo tháng")
    @DecimalMin(value = "0.01", message = "Giá cơ bản phải lớn hơn 0")
    private BigDecimal basePricePerMonth;

    @NotNull(message = "Vui lòng nhập tiền cọc")
    @DecimalMin(value = "0.00", message = "Tiền cọc không được âm")
    private BigDecimal depositAmount;
}
