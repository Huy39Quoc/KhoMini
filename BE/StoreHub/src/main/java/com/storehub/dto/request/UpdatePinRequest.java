package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdatePinRequest {

    @NotBlank(message = "PIN cannot be blank")
    @Pattern(regexp = "^[0-9]{6}$", message = "PIN must consist of exactly 6 digits")
    private String newPin;
}