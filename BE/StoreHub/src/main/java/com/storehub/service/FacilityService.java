package com.storehub.service;

import com.storehub.common.response.PageResponse;
import com.storehub.dto.request.FacilityCreateRequest;
import com.storehub.dto.request.FacilityUpdateRequest;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.enums.FacilityStatus;

import java.util.UUID;

public interface FacilityService {
    FacilityResponse getById(UUID id);
    FacilityResponse create(FacilityCreateRequest request);
    FacilityResponse update(UUID id, FacilityUpdateRequest request);
    void delete(UUID id);
    PageResponse<FacilityResponse> getAll(String search, FacilityStatus status, int page, int size, String sortBy, String sortDir);
}