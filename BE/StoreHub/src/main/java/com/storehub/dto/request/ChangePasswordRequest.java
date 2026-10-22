package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChangePasswordRequest {

    @NotBlank(message = "Vui lòng nhập mật khẩu cũ")
    private String oldPassword;

    @NotBlank(message = "Vui lòng nhập mật khẩu mới")
    @Size(min = 5, message = "Mật khẩu mới phải dài hơn 5 ký tự")
    private String newPassword;

    @NotBlank(message = "Vui lòng nhập mật khẩu xác nhận")
    private String confirmPassword;
}