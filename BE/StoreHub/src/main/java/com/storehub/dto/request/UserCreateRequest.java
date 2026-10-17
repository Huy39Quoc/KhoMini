package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserCreateRequest {

    @NotBlank(message = "Username is required")
    @Size(min = 3, max = 30, message = "Username must be between 3 and 30 characters")
    private String username;

    @NotBlank(message = "Vui lòng nhập email")
    @Pattern(
            regexp = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$",
            message = "Email không đúng định dạng"
    )
    @Size(max = 255, message = "Email tối đa 255 ký tự")
    private String email;

    @NotBlank(message = "Vui lòng nhập mật khẩu")
    @Size(min = 5, message = "Mật khẩu phải dài hơn 5 ký tự")
    private String password;

    @NotBlank(message = "Vui lòng nhập họ tên")
    @Size(max = 30, message = "Họ tên tối đa 30 ký tự")
    private String fullName;

    @NotBlank(message = "Vui lòng nhập số điện thoại")
    @Pattern(
        regexp = "^(0|\\+84)(3|5|7|8|9)[0-9]{8}$",
        message = "Số điện thoại Việt Nam không hợp lệ"
    )
    private String phone;
    // Admin assigns role when creating a user
    // If null, service will default to "customer"
    private UUID roleId;
}