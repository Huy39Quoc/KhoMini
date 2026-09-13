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

    @NotBlank(message = "Mã PIN không được để trống")
    @Pattern(regexp = "^[0-9]{6}$", message = "Mã PIN phải bao gồm đúng 6 chữ số")
    private String newPin;
}