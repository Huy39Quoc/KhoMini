package com.storehub.dto.request;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.util.List;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RolePermissionBulkAssignRequest {

    @NotNull(message = "Vui lòng chọn vai trò")
    private UUID roleId;

    @NotEmpty(message = "Danh sách quyền không được để trống")
    private List<UUID> permissionIds;
}
