package com.storehub.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ResetPasswordRequest {

    @NotBlank(message = "Thiếu mã xác thực")
    private String token;

    @NotBlank(message = "Vui lòng nhập mật khẩu mới")
    @Size(min = 5, message = "Mật khẩu mới tối thiểu 5 ký tự")
    private String newPassword;

    @NotBlank(message = "Vui lòng nhập mật khẩu xác nhận")
    private String confirmPassword;
}