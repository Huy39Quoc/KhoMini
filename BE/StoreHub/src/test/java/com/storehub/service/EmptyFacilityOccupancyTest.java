package com.storehub.service;

import com.storehub.dto.response.OccupancyReportResponse;
import com.storehub.entity.Facility;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.service.impl.ReportServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EmptyFacilityOccupancyTest {
    @Mock PaymentRepository payments;
    @Mock RefundRequestRepository refunds;
    @Mock StorageUnitRepository units;
    @Mock BookingRepository bookings;
    @Mock FacilityRepository facilities;
    @Mock UnitTypeRepository types;
    @InjectMocks ReportServiceImpl reports;

    @Test
    void newlyCreatedFacilityAppearsBeforeItsFirstStorageUnit() {
        Facility facility = Facility.builder().name("abb").code("ABB").build();
        facility.setId(UUID.randomUUID());
        when(facilities.findAllByOrderByCreatedAtAsc()).thenReturn(List.of(facility));

        OccupancyReportResponse result = reports.getOccupancyReport();

        assertEquals(1, result.getByFacility().size());
        assertEquals(facility.getId(), result.getByFacility().get(0).getFacilityId());
        assertEquals(0, result.getByFacility().get(0).getTotalUnits());
        assertEquals(0.0, result.getByFacility().get(0).getOccupancyRate());
    }
}
