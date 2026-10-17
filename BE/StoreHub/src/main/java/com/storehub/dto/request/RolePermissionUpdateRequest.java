package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RolePermissionUpdateRequest {

    @Size(max = 255, message = "Mô tả tối đa 255 ký tự")
    private String description;

    private Boolean isActive;
}
