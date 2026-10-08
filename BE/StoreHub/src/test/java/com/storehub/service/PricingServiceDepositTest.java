package com.storehub.service;

import com.storehub.entity.FacilityPolicy;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.service.impl.PricingServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PricingServiceDepositTest {
    @Mock FacilityPolicyService facilityPolicyService;
    @Mock UnitTypeRepository unitTypeRepository;
    @Mock StorageUnitRepository storageUnitRepository;
    @Mock FacilityPolicyRepository facilityPolicyRepository;
    @Mock FacilityRepository facilityRepository;
    @InjectMocks PricingServiceImpl pricingService;

    @Test
    void appliesFacilityDepositPercentage() {
        UUID facilityId = UUID.randomUUID();
        when(facilityPolicyRepository.findByFacility_Id(facilityId))
                .thenReturn(Optional.of(FacilityPolicy.builder()
                        .depositPercentage(75.0).build()));

        assertEquals(BigDecimal.valueOf(150000), pricingService.calculateDepositAmount(
                facilityId, BigDecimal.valueOf(200000), BigDecimal.valueOf(30000)));
    }

    @Test
    void fallsBackToUnitTypeDepositWhenNoPolicy() {
        UUID facilityId = UUID.randomUUID();
        when(facilityPolicyRepository.findByFacility_Id(facilityId))
                .thenReturn(Optional.empty());

        assertEquals(BigDecimal.valueOf(30000), pricingService.calculateDepositAmount(
                facilityId, BigDecimal.valueOf(200000), BigDecimal.valueOf(30000)));
    }
}
