package com.storehub.dto.request;

import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// Tạo PIN lần đầu. Bỏ trống newPin = để hệ thống tự tạo; có newPin = khách tự đặt.
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SetupPinRequest {

    @Pattern(regexp = "^[0-9]{6}$", message = "PIN must consist of exactly 6 digits")
    private String newPin;
}
