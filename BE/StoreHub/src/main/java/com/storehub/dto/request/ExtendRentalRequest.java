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

    @NotNull(message = "Number of extension months cannot be null")
    @Min(value = 1, message = "Extension period must be at least 1 month")
    @Max(value = 36, message = "Extension period cannot exceed 36 months")
    private Integer extraMonths;
}