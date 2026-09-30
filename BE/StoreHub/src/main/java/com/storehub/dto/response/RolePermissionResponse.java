package com.storehub.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RolePermissionResponse {
    private UUID id;

    private UUID roleId;
    private String roleName;

    private UUID permissionId;
    private String permissionName;
    private String permissionGroup;

    @JsonProperty("isActive")
    private boolean isActive;
    private String description;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
