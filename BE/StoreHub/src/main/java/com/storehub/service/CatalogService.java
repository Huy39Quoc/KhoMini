package com.storehub.service;

import com.storehub.dto.response.CatalogOverviewResponse;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.dto.response.UnitTypeCatalogResponse;

import java.util.List;
import java.util.UUID;

public interface CatalogService {
    CatalogOverviewResponse getCatalogOverview(UUID facilityId);
    List<FacilityResponse> getAllFacilities();
    List<UnitTypeCatalogResponse> getUnitTypes(UUID facilityId);
}