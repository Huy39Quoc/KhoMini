package com.storehub.mapper;
import com.storehub.dto.request.RoleCreateRequest;
import com.storehub.dto.request.RoleUpdateRequest;
import com.storehub.dto.response.RoleResponse;
import com.storehub.entity.Role;
import org.mapstruct.*;

@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE
)
public interface RoleMapper {
    Role toEntity(RoleCreateRequest request);
    RoleResponse toResponse(Role entity);

    //ignore and not update the field(s) that has null value
    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntityFromRequest(RoleUpdateRequest request, @MappingTarget Role role);
}
