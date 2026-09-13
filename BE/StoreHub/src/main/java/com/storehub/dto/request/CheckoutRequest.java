package com.storehub.dto.request;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class CheckoutRequest {

    @NotNull(message = "Scheduled return time cannot be null")
    @Future(message = "Scheduled return time must be in the future")
    private LocalDateTime scheduledReturnTime;

    private String notes;
}