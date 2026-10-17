package com.storehub.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ExtendRentalRequest {

    @NotNull(message = "Vui lòng nhập số tháng gia hạn")
    @Min(value = 1, message = "Thời gian gia hạn tối thiểu 1 tháng")
    @Max(value = 36, message = "Thời gian gia hạn tối đa 36 tháng")
    private Integer extraMonths;

    private String paymentMethod;
}