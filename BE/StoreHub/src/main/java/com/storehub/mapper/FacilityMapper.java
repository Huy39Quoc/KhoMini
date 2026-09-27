package com.storehub.mapper;

import com.storehub.dto.request.FacilityCreateRequest;
import com.storehub.dto.request.FacilityUpdateRequest;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.entity.Facility;
import org.mapstruct.*;

@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE
)
public interface FacilityMapper {

    @Mapping(target = "manager", ignore = true) // resolved from managerId in the service
    Facility toEntity(FacilityCreateRequest request);

    @Mapping(source = "manager.id", target = "managerId")
    @Mapping(source = "manager.fullName", target = "managerName")
    FacilityResponse toResponse(Facility entity);

    // manager/status are resolved/parsed explicitly in the service, so they're excluded here;
    // everything else (name/code/address/city/contactPhone/email/openTime/closeTime/description) patches directly.
    @Mapping(target = "manager", ignore = true)
    @Mapping(target = "status", ignore = true)
    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntityFromRequest(FacilityUpdateRequest request, @MappingTarget Facility entity);
}