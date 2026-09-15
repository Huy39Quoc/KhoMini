package com.storehub.dto.request;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RentalQuoteRequest {

    private UUID unitTypeId;
    private UUID storageUnitId;

    @NotNull(message = "Start date is required")
    @FutureOrPresent(message = "Start date must be today or in the future")
    private LocalDate startDate;

    @NotNull(message = "Rental months is required")
    @Min(value = 1, message = "Rental period must be at least 1 month")
    @Max(value = 36, message = "Rental period cannot exceed 36 months")
    private Integer rentalMonths;
}