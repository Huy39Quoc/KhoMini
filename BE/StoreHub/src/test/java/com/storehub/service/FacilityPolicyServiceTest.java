package com.storehub.service;

import com.storehub.dto.response.OverdueConfigResponse;
import com.storehub.entity.Facility;
import com.storehub.entity.FacilityPolicy;
import com.storehub.mapper.FacilityPolicyMapper;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.service.impl.FacilityPolicyServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FacilityPolicyServiceTest {

    @Mock
    private FacilityPolicyRepository facilityPolicyRepository;

    @Mock
    private FacilityRepository facilityRepository;

    @Mock
    private FacilityPolicyMapper facilityPolicyMapper;

    @Mock
    private ActivityLogService activityLogService;

    @InjectMocks
    private FacilityPolicyServiceImpl facilityPolicyService;

    private UUID facilityId;
    private FacilityPolicy policy;

    @BeforeEach
    void setUp() {
        facilityId = UUID.randomUUID();
        Facility facility = Facility.builder().name("District 1").build();
        facility.setId(facilityId);

        policy = FacilityPolicy.builder()
                .facility(facility)
                .depositPercentage(75.0)
                .renewalWindowDays(5)
                .minimumRentalMonths(2)
                .returnNoticeDays(3)
                .overdueGraceDays(2)
                .dailyLateFee(BigDecimal.valueOf(50000))
                .overdueAccessDisableDays(4)
                .overdueSealingDays(10)
                .build();
    }

    @Test
    void testResolveDepositPercentage_ReturnsPolicyValue() {
        when(facilityPolicyRepository.findByFacility_Id(facilityId)).thenReturn(Optional.of(policy));

        Double depositPct = facilityPolicyService.resolveDepositPercentage(facilityId);
        assertEquals(75.0, depositPct);
    }

    @Test
    void testResolveDepositPercentage_ReturnsDefaultWhenNoPolicy() {
        when(facilityPolicyRepository.findByFacility_Id(facilityId)).thenReturn(Optional.empty());

        Double depositPct = facilityPolicyService.resolveDepositPercentage(facilityId);
        assertEquals(100.0, depositPct);
    }

    @Test
    void testIsMinRentalMonthsSatisfied_TrueWhenSatisfied() {
        when(facilityPolicyRepository.findByFacility_Id(facilityId)).thenReturn(Optional.of(policy));

        assertTrue(facilityPolicyService.isMinRentalMonthsSatisfied(facilityId, 2));
        assertTrue(facilityPolicyService.isMinRentalMonthsSatisfied(facilityId, 3));
    }

    @Test
    void testIsMinRentalMonthsSatisfied_FalseWhenBelowMinimum() {
        when(facilityPolicyRepository.findByFacility_Id(facilityId)).thenReturn(Optional.of(policy));

        assertFalse(facilityPolicyService.isMinRentalMonthsSatisfied(facilityId, 1));
    }

    @Test
    void testIsWithinRenewalWindow_InsideWindow() {
        when(facilityPolicyRepository.findByFacility_Id(facilityId)).thenReturn(Optional.of(policy));

        // Policy renewalWindowDays = 5. Window opens 5 days before endDate.
        LocalDate endDate = LocalDate.now().plusDays(3); // within 5 days
        assertTrue(facilityPolicyService.isWithinRenewalWindow(facilityId, endDate));
    }

    @Test
    void testIsWithinRenewalWindow_TooEarly() {
        when(facilityPolicyRepository.findByFacility_Id(facilityId)).thenReturn(Optional.of(policy));

        LocalDate endDate = LocalDate.now().plusDays(10); // 10 days away, window opens in 5 days
        assertFalse(facilityPolicyService.isWithinRenewalWindow(facilityId, endDate));
    }

    @Test
    void testIsReturnNoticeSatisfied_SufficientNotice() {
        when(facilityPolicyRepository.findByFacility_Id(facilityId)).thenReturn(Optional.of(policy));

        // Policy returnNoticeDays = 3
        LocalDateTime returnTime = LocalDateTime.now().plusDays(4);
        assertTrue(facilityPolicyService.isReturnNoticeSatisfied(facilityId, returnTime));
    }

    @Test
    void testIsReturnNoticeSatisfied_InsufficientNotice() {
        when(facilityPolicyRepository.findByFacility_Id(facilityId)).thenReturn(Optional.of(policy));

        LocalDateTime returnTime = LocalDateTime.now().plusDays(1);
        assertFalse(facilityPolicyService.isReturnNoticeSatisfied(facilityId, returnTime));
    }

    @Test
    void testGetOverdueConfig_ReturnsConfigValues() {
        when(facilityPolicyRepository.findByFacility_Id(facilityId)).thenReturn(Optional.of(policy));

        OverdueConfigResponse config = facilityPolicyService.getOverdueConfig(facilityId);
        assertNotNull(config);
        assertEquals(2, config.graceDays());
        assertEquals(BigDecimal.valueOf(50000), config.dailyLateFee());
        assertEquals(4, config.accessDisableDays());
        assertEquals(10, config.sealingDays());
    }
}
