package com.storehub.dto.request;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;
import java.util.UUID;

@Data
@Builder
public class BookingCreationRequest {

    @NotNull(message = "Facility ID is required")
    private UUID facilityId;

    @NotNull(message = "Unit type ID is required")
    private UUID unitTypeId;

    @NotNull(message = "Start date is required")
    @Future(message = "Start date must be in the future")
    private LocalDate startDate;

    @NotNull(message = "Rental months is required")
    @Min(value = 1, message = "Rental months must be at least 1")
    private Integer rentalMonths;
}
