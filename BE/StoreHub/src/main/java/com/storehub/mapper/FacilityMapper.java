package com.storehub.mapper;

import com.storehub.dto.request.FacilityCreateRequest;
import com.storehub.dto.request.FacilityUpdateRequest;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.entity.Facility;
import org.mapstruct.*;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE
)
public interface FacilityMapper {

    @Mapping(target = "manager", ignore = true) // resolved from managerId in the service
    @Mapping(target = "status", ignore = true)
    @Mapping(target = "images", source = "images")
    Facility toEntity(FacilityCreateRequest request);

    @Mapping(source = "manager.id", target = "managerId")
    @Mapping(source = "manager.fullName", target = "managerName")
    @Mapping(target = "images", source = "images")
    FacilityResponse toResponse(Facility entity);

    @AfterMapping
    default void afterToResponse(Facility entity, @MappingTarget FacilityResponse response) {
        response.setImages(entity.getImageList());
    }

    // manager/status are resolved/parsed explicitly in the service, so they're excluded here;
    // everything else (name/code/address/city/contactPhone/email/openTime/closeTime/description) patches directly.
    @Mapping(target = "manager", ignore = true)
    @Mapping(target = "status", ignore = true)
    @Mapping(target = "images", source = "images")
    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntityFromRequest(FacilityUpdateRequest request, @MappingTarget Facility entity);

    default List<String> mapImages(String images) {
        if (images != null && !images.trim().isEmpty()) {
            return Arrays.stream(images.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .collect(Collectors.toList());
        }
        return Collections.emptyList();
    }

    default String mapImageList(List<String> list) {
        if (list == null || list.isEmpty()) return null;
        return String.join(",", list);
    }
}