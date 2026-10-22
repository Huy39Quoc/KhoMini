package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.exception.AppException;
import com.storehub.repository.*;
import com.storehub.service.impl.PricingServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.verifyNoInteractions;

@ExtendWith(MockitoExtension.class)
class CancellationPolicySnapshotTest {
    @Mock FacilityPolicyService policies;
    @Mock UnitTypeRepository types;
    @Mock StorageUnitRepository units;
    @Mock FacilityPolicyRepository policyRepository;
    @Mock FacilityRepository facilities;
    @InjectMocks PricingServiceImpl pricing;

    @Test
    void refundUsesBookedRulesAtAllBoundariesWithoutReadingCurrentPolicy() {
        Booking booking = Booking.builder().cancellationFullRefundHours(48)
                .cancellationPartialRefundHours(24).cancellationPartialRefundPercent(50.0).build();
        LocalDateTime start = LocalDateTime.of(2027, 1, 10, 18, 0);
        BigDecimal paid = new BigDecimal("1000");
        assertEquals(paid, pricing.calculateCancellationRefund(booking, paid, start, start.minusHours(48)));
        assertEquals(new BigDecimal("500"), pricing.calculateCancellationRefund(booking, paid, start, start.minusHours(24)));
        assertEquals(BigDecimal.ZERO, pricing.calculateCancellationRefund(booking, paid, start, start.minusHours(24).plusSeconds(1)));
        assertEquals(BigDecimal.ZERO, pricing.calculateCancellationRefund(booking, paid, start, start.plusHours(1)));
        verifyNoInteractions(policyRepository, policies);
    }

    @Test
    void missingSnapshotCannotSilentlyUseTodaysPolicy() {
        LocalDateTime start = LocalDateTime.of(2027, 1, 10, 18, 0);
        assertThrows(AppException.class, () -> pricing.calculateCancellationRefund(
                new Booking(), BigDecimal.TEN, start, start.minusDays(3)));
        verifyNoInteractions(policyRepository);
    }
}
