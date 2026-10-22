package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

import java.util.UUID;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserUpdateRequest {

    @Size(min = 3, max = 30, message = "Username must be between 3 and 30 characters")
    private String username;

    @Size(min=3, max = 30, message = "Họ tên phải từ 3 đến 30 ký tự")
    private String fullName;

    private Boolean isActive;

    @NotBlank(message = "Vui lòng nhập số điện thoại")
    @Pattern(
        regexp = "^(0|\\+84)(3|5|7|8|9)[0-9]{8}$",
        message = "Số điện thoại Việt Nam không hợp lệ"
    )
    private String phone;
    
    // Only admin can change role
    private UUID roleId;
}