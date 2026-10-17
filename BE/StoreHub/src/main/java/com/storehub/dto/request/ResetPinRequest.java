package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// Quên PIN: xác minh bằng mật khẩu tài khoản, rồi tự đặt PIN mới hoặc để hệ thống tạo.
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ResetPinRequest {

    @NotBlank(message = "Vui lòng nhập mật khẩu tài khoản")
    private String password;

    @Pattern(regexp = "^[0-9]{6}$", message = "Mã PIN phải gồm đúng 6 chữ số")
    private String newPin;
}
