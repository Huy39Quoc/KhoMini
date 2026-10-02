package com.storehub.service;

import com.storehub.dto.request.UpdateUnitTypePriceRequest;
import com.storehub.dto.response.UnitTypeCatalogResponse;

import java.util.UUID;

public interface UnitTypeManagementService {

    UnitTypeCatalogResponse updatePrice(UUID unitTypeId, UpdateUnitTypePriceRequest request);
}
