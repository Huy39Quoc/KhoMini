package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalTime;
import java.util.List;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FacilityUpdateRequest {

    @Size(min = 2, max = 150, message = "Tên cơ sở phải từ 2 đến 150 ký tự")
    private String name;

    @Size(min = 2, max = 30, message = "Mã cơ sở phải từ 2 đến 30 ký tự")
    private String code;

    @Size(max = 255, message = "Địa chỉ tối đa 255 ký tự")
    private String address;

    @Size(max = 50, message = "Thành phố tối đa 50 ký tự")
    private String city;

    @Size(max = 20, message = "Số điện thoại liên hệ tối đa 20 ký tự")
    private String contactPhone;

    @Email(message = "Email không hợp lệ")
    @Size(max = 150, message = "Email tối đa 150 ký tự")
    private String email;

    private UUID managerId;

    private String status; // FacilityStatus name — validated/parsed in the service

    private LocalTime openTime;
    private LocalTime closeTime;

    private String description;

    private Boolean airConditioned24h;

    private String imageUrl;
    private List<String> images;
}
