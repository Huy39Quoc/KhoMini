package com.storehub.service.impl;

import com.storehub.dto.response.CatalogOverviewResponse;
import com.storehub.dto.response.FacilityResponse;
import com.storehub.dto.response.UnitTypeCatalogResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.UnitType;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.service.CatalogService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CatalogServiceImpl implements CatalogService {

    private final FacilityRepository facilityRepository;
    private final UnitTypeRepository unitTypeRepository;

    @Override
    @Transactional(readOnly = true)
    public CatalogOverviewResponse getCatalogOverview(UUID facilityId) {
        return CatalogOverviewResponse.builder()
                .facilities(getAllFacilities())
                .unitTypes(getUnitTypes(facilityId))
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public List<FacilityResponse> getAllFacilities() {
        return facilityRepository.findAllByOrderByCreatedAtAsc()
                .stream()
                .map(this::mapToFacilityResponse)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional(readOnly = true)
    public List<UnitTypeCatalogResponse> getUnitTypes(UUID facilityId) {
        List<Object[]> results = unitTypeRepository.findCatalogUnitTypesWithAvailableCount(facilityId);
        return results.stream().map(row -> {
            UnitType ut = (UnitType) row[0];
            Long count = (Long) row[1];
            return UnitTypeCatalogResponse.builder()
                    .id(ut.getId())
                    .typeName(ut.getTypeName())
                    .dimensions(ut.getDimensions())
                    .areaSqm(ut.getAreaSqm())
                    .basePricePerMonth(ut.getBasePricePerMonth())
                    .depositAmount(ut.getDepositAmount())
                    .availableUnitsCount(count)
                    .build();
        }).collect(Collectors.toList());
    }

    private FacilityResponse mapToFacilityResponse(Facility f) {
        return FacilityResponse.builder()
                .id(f.getId())
                .name(f.getName())
                .address(f.getAddress())
                .city(f.getCity())
                .contactPhone(f.getContactPhone())
                .createdAt(f.getCreatedAt())
                .build();
    }
}