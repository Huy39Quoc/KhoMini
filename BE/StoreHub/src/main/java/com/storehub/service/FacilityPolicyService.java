package com.storehub.service;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.FacilityPolicyCreateRequest;
import com.storehub.dto.request.FacilityPolicyUpdateRequest;
import com.storehub.dto.response.FacilityPolicyResponse;

import java.util.UUID;

public interface FacilityPolicyService {

    FacilityPolicyResponse getById(UUID id);

    FacilityPolicyResponse getByFacilityId(UUID facilityId);

    FacilityPolicyResponse create(FacilityPolicyCreateRequest request);

    FacilityPolicyResponse update(UUID id, FacilityPolicyUpdateRequest request);

    void delete(UUID id);

    PageResponse<FacilityPolicyResponse> getAll(
            String search,
            int page,
            int size,
            String sortBy,
            String sortDir
    );
}