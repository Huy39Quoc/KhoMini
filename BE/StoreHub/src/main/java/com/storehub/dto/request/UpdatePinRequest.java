package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// Đổi PIN: phải nhập đúng PIN hiện tại.
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UpdatePinRequest {

    @NotBlank(message = "Vui lòng nhập mã PIN hiện tại")
    @Pattern(regexp = "^[0-9]{6}$", message = "Mã PIN phải gồm đúng 6 chữ số")
    private String currentPin;

    @NotBlank(message = "Vui lòng nhập mã PIN")
    @Pattern(regexp = "^[0-9]{6}$", message = "Mã PIN phải gồm đúng 6 chữ số")
    private String newPin;
}
