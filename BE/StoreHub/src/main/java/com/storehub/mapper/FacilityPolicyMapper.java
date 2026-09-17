package com.storehub.mapper;

import com.storehub.dto.request.FacilityPolicyUpdateRequest;
import com.storehub.dto.response.FacilityPolicyResponse;
import com.storehub.entity.FacilityPolicy;
import org.mapstruct.*;

@Mapper(
        componentModel = "spring",
        nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE
)
public interface FacilityPolicyMapper {

    @Mapping(source = "facility.id", target = "facilityId")
    @Mapping(source = "facility.name", target = "facilityName")
    FacilityPolicyResponse toResponse(FacilityPolicy entity);

    // facility is resolved from facilityId and set explicitly in the service, so only
    // depositPercentage/dailyLateFee/cancellationRefundDays are patched here.
    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntityFromRequest(FacilityPolicyUpdateRequest request, @MappingTarget FacilityPolicy entity);
}
