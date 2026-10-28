package com.storehub.service;

import com.storehub.dto.request.*;
import com.storehub.dto.response.OverdueConfigResponse;
import com.storehub.entity.*;
import com.storehub.enums.ActivityAction;
import com.storehub.exception.*;
import com.storehub.mapper.FacilityPolicyMapper;
import com.storehub.repository.*;
import com.storehub.scheduler.OverdueScheduler;
import com.storehub.service.impl.FacilityPolicyServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OverdueTimelineTest {
    @Mock FacilityPolicyRepository repository;
    @Mock FacilityRepository facilities;
    @Mock FacilityPolicyMapper mapper;
    @Mock ActivityLogService logs;
    @Mock BookingRepository bookings;
    @Mock PaymentRepository payments;
    @Mock FacilityPolicyService policyReader;
    @Mock PricingService pricing;
    @InjectMocks FacilityPolicyServiceImpl policies;
    @InjectMocks OverdueScheduler scheduler;

    @ParameterizedTest
    @CsvSource({"10,3,7", "1,7,3", "-1,3,7", "0,-1,7", "0,0,-1"})
    void invalidCreateCannotPersistPolicy(int grace, int disable, int sealing) {
        var request = FacilityPolicyCreateRequest.builder().overdueGraceDays(grace)
                .overdueAccessDisableDays(disable).overdueSealingDays(sealing).build();
        var error = assertThrows(AppException.class, () -> policies.create(request));
        assertEquals(ErrorCode.FACILITY_POLICY_INVALID_OVERDUE_TIMELINE, error.getErrorCode());
        verifyNoInteractions(repository, facilities, mapper);
    }

    @ParameterizedTest
    @CsvSource({"0,0,0", "1,3,7", "3,3,3"})
    void validCreateAllowsOrderedAndEqualThresholds(int grace, int disable, int sealing) {
        UUID id = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(id);
        when(facilities.findById(id)).thenReturn(Optional.of(facility));
        when(repository.save(any())).thenAnswer(call -> call.getArgument(0));
        var request = FacilityPolicyCreateRequest.builder().facilityId(id).overdueGraceDays(grace)
                .overdueAccessDisableDays(disable).overdueSealingDays(sealing).build();
        assertDoesNotThrow(() -> policies.create(request));
        verify(repository).save(argThat(p -> p.getOverdueGraceDays() == grace
                && p.getOverdueAccessDisableDays() == disable && p.getOverdueSealingDays() == sealing));
    }

    @ParameterizedTest
    @CsvSource(value = {"10,null,null", "null,0,null", "null,null,2", "-1,null,null"}, nullValues = "null")
    void partialUpdateIsValidatedAgainstStoredThresholds(Integer grace, Integer disable, Integer sealing) {
        UUID id = UUID.randomUUID();
        FacilityPolicy policy = FacilityPolicy.builder().overdueGraceDays(1)
                .overdueAccessDisableDays(3).overdueSealingDays(7).build();
        when(repository.lockById(id)).thenReturn(Optional.of(policy));
        var request = FacilityPolicyUpdateRequest.builder().overdueGraceDays(grace)
                .overdueAccessDisableDays(disable).overdueSealingDays(sealing).build();
        var error = assertThrows(AppException.class, () -> policies.update(id, request));
        assertEquals(ErrorCode.FACILITY_POLICY_INVALID_OVERDUE_TIMELINE, error.getErrorCode());
        verify(repository, never()).save(any());
        verifyNoInteractions(mapper);
    }

    @Test
    void fullUpdateCanRepairAnInvalidLegacyTimeline() {
        UUID id = UUID.randomUUID();
        FacilityPolicy policy = FacilityPolicy.builder().overdueGraceDays(10)
                .overdueAccessDisableDays(3).overdueSealingDays(7).build();
        policy.setId(id);
        when(repository.lockById(id)).thenReturn(Optional.of(policy));
        when(repository.save(policy)).thenReturn(policy);
        assertDoesNotThrow(() -> policies.update(id, FacilityPolicyUpdateRequest.builder()
                .overdueGraceDays(1).overdueAccessDisableDays(3).overdueSealingDays(7).build()));
        verify(repository).save(policy);
    }

    @ParameterizedTest
    @CsvSource({
            "1,3,7,1,false,false,0",
            "1,3,7,2,false,false,1",
            "1,3,7,3,true,false,2",
            "1,3,7,7,true,true,6",
            "3,3,7,3,true,false,0",
            "3,3,3,3,true,true,0",
            "0,0,0,0,false,false,0",
            "0,0,0,1,true,true,1",
            "10,3,7,3,true,false,0",
            "10,3,7,7,true,true,0"
    })
    void securityDeadlinesDoNotDependOnChargeableDays(int grace, int disable, int sealing,
            int overdueDays, boolean accessDisabled, boolean sealingPending, int chargeableDays) {
        UUID facilityId = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(facilityId);
        LocalDate end = LocalDate.of(2026, 1, 1);
        Booking booking = Booking.builder().overdueDailyLateFee(new BigDecimal("10.00"))
                .overdueGraceDays(grace).overdueAccessDisableDays(disable).overdueSealingDays(sealing)
                .bookingCode("BK-TIMELINE").endDate(end)
                .storageUnit(StorageUnit.builder().facility(facility).build())
                .accessPin("hashed-pin").accessCode("old-code").unitLocked(false).build();
        booking.setId(UUID.randomUUID());
        LocalDate today = end.plusDays(overdueDays);
        ReflectionTestUtils.invokeMethod(scheduler, "processOneBooking", booking, today, today.atTime(0, 5));
        assertEquals(accessDisabled, booking.getAccessDisabledAt() != null);
        assertEquals(sealingPending, booking.getSealingPendingAt() != null);
        assertEquals(0, BigDecimal.TEN.multiply(BigDecimal.valueOf(chargeableDays)).compareTo(booking.getOverdueFeeAccrued()));
        if (accessDisabled) {
            assertNull(booking.getAccessPin());
            assertNull(booking.getAccessCode());
            assertTrue(booking.getUnitLocked());
        }
        if (chargeableDays == 0) verifyNoInteractions(pricing, payments);
        // Re-running the same day must not repeat security transitions or charges.
        ReflectionTestUtils.invokeMethod(scheduler, "processOneBooking", booking, today, today.atTime(0, 6));
        if (accessDisabled) verify(logs, times(1)).recordSystem(eq(ActivityAction.OVERDUE_ACCESS_DISABLED), anyString(), any(), anyString());
        if (sealingPending) verify(logs, times(1)).recordSystem(eq(ActivityAction.OVERDUE_SEALING_PENDING), anyString(), any(), anyString());
        if (chargeableDays > 0) verify(payments, times(1)).save(any());
    }
}
