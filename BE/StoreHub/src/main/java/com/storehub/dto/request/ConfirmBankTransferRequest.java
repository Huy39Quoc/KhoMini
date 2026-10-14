package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConfirmBankTransferRequest {

    @NotBlank(message = "Transfer reference is required")
    private String transferReference;

    private String notes;
}
