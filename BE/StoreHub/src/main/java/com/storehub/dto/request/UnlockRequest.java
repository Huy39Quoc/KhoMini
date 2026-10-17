package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UnlockRequest {

    @NotBlank(message = "Vui lòng nhập mã PIN")
    @Pattern(regexp = "^[0-9]{6}$", message = "Mã PIN phải gồm đúng 6 chữ số")
    private String pin;
}
