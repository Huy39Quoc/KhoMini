package com.storehub.dto.request;

import jakarta.validation.constraints.*;
import lombok.*;

import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RolePermissionCreateRequest {

    @NotNull(message = "Vui lòng chọn vai trò")
    private UUID roleId;

    @NotNull(message = "Vui lòng chọn quyền")
    private UUID permissionId;

    @Size(max = 255, message = "Mô tả tối đa 255 ký tự")
    private String description;
}
