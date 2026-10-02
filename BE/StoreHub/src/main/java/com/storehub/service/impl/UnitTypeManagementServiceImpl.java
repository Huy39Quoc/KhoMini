package com.storehub.service.impl;

import com.storehub.dto.request.UpdateUnitTypePriceRequest;
import com.storehub.dto.response.UnitTypeCatalogResponse;
import com.storehub.entity.UnitType;
import com.storehub.enums.ActivityAction;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.UnitTypeManagementService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UnitTypeManagementServiceImpl implements UnitTypeManagementService {

    private final UnitTypeRepository unitTypeRepository;
    private final ActivityLogService activityLogService;

    @Override
    @Transactional
    public UnitTypeCatalogResponse updatePrice(
            UUID unitTypeId,
            UpdateUnitTypePriceRequest request
    ) {
        UnitType unitType = unitTypeRepository.findById(unitTypeId)
                .orElseThrow(() -> new AppException(ErrorCode.UNIT_TYPE_NOT_FOUND));

        BigDecimal oldPrice = unitType.getBasePricePerMonth();
        BigDecimal oldDeposit = unitType.getDepositAmount();

        unitType.setBasePricePerMonth(request.getBasePricePerMonth());
        unitType.setDepositAmount(request.getDepositAmount());

        UnitType saved = unitTypeRepository.save(unitType);

        activityLogService.record(
                ActivityAction.PRICE_UPDATE,
                "UNIT_TYPE",
                saved.getId(),
                "Updated price of unit type " + saved.getTypeName(),
                "price=" + oldPrice + ", deposit=" + oldDeposit,
                "price=" + saved.getBasePricePerMonth()
                        + ", deposit=" + saved.getDepositAmount()
        );

        return UnitTypeCatalogResponse.builder()
                .id(saved.getId())
                .typeName(saved.getTypeName())
                .dimensions(saved.getDimensions())
                .areaSqm(saved.getAreaSqm())
                .basePricePerMonth(saved.getBasePricePerMonth())
                .depositAmount(saved.getDepositAmount())
                .build();
    }
}
