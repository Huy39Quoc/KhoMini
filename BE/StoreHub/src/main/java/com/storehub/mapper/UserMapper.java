package com.storehub.mapper;
import com.storehub.dto.request.UserCreateRequest;
import com.storehub.dto.request.UserUpdateRequest;
import com.storehub.dto.response.UserResponse;
import com.storehub.entity.User;
import org.mapstruct.*;
@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE
)
public interface UserMapper {
    User toEntity(UserCreateRequest request);
    UserResponse toResponse(User user);
    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntityFromRequest(UserUpdateRequest request, @MappingTarget User user);
}
