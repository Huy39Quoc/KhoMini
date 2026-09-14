package com.storehub.mapper;

import com.storehub.dto.request.PermissionCreateRequest;
import com.storehub.dto.request.PermissionUpdateRequest;
import com.storehub.dto.response.PermissionResponse;
import com.storehub.entity.Permission;
import org.mapstruct.*;

@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE
)
public interface PermissionMapper {
    Permission toEntity(PermissionCreateRequest request);
    PermissionResponse toResponse(Permission entity);

    //ignore and not update the field(s) that has null value
    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntityFromRequest(PermissionUpdateRequest request, @MappingTarget Permission permission);
}
