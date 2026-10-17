package com.storehub.service;

import com.storehub.entity.Facility;
import com.storehub.enums.FacilityStatus;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.service.impl.CatalogServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CatalogAirConditioningTest {
    @Mock FacilityRepository facilities;
    @Mock UnitTypeRepository unitTypes;
    @InjectMocks CatalogServiceImpl catalog;

    @Test
    void advertisesCoolingOnlyForFacilitiesExplicitlyMarkedByAdmin() {
        Facility cooled = Facility.builder().name("A")
                .airConditioned24h(true).build();
        Facility ordinary = Facility.builder().name("B").build();
        when(facilities.findByStatusOrderByCreatedAtAsc(FacilityStatus.ACTIVE))
                .thenReturn(List.of(cooled, ordinary));

        var available = catalog.getAllFacilities();

        assertEquals(true, available.get(0).getAirConditioned24h());
        assertEquals(false, available.get(1).getAirConditioned24h());
    }
}
