package com.storehub.service;

import com.storehub.dto.request.BookingCreationRequest;
import com.storehub.dto.response.FacilityPolicyResponse;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.entity.*;
import com.storehub.enums.FacilityStatus;
import com.storehub.exception.*;
import com.storehub.repository.*;
import com.storehub.service.impl.BookingServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BookingTermsAcceptanceTest {
    @Mock BookingRepository bookings;
    @Mock PaymentRepository payments;
    @Mock FacilityRepository facilities;
    @Mock StorageUnitRepository units;
    @Mock UserRepository users;
    @Mock PricingService pricing;
    @Mock WaitlistService waitlist;
    @Mock FacilityPolicyService policies;
    @Mock PaymentService paymentService;
    @InjectMocks BookingServiceImpl service;
    BookingCreationRequest request;
    FacilityPolicyResponse policy;
    Facility facility;

    @BeforeEach
    void setup() {
        UUID facilityId = UUID.randomUUID();
        facility = Facility.builder().status(FacilityStatus.ACTIVE)
                .openTime(LocalTime.of(8, 0)).closeTime(LocalTime.of(20, 0)).build();
        facility.setId(facilityId);
        policy = FacilityPolicyResponse.builder().termsVersion("v1").termsAndConditions("Original terms")
                .prohibitedItems("Original prohibited items").cancellationFullRefundHours(48)
                .cancellationPartialRefundHours(24).cancellationPartialRefundPercent(50.0).build();
        request = BookingCreationRequest.builder().facilityId(facilityId).unitTypeId(UUID.randomUUID())
                .startDate(LocalDate.now().plusDays(2)).checkInTime(LocalTime.of(9, 0)).rentalMonths(1)
                .termsConfirmed(true).prohibitedItemsConfirmed(true)
                .termsVersion(policy.getTermsVersion()).termsHash(policy.getTermsHash()).build();
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(new User()));
        when(facilities.findById(facilityId)).thenReturn(Optional.of(facility));
        when(policies.isMinRentalMonthsSatisfied(facilityId, 1)).thenReturn(true);
        when(policies.isAdvanceReservationAllowed(facilityId, request.getStartDate())).thenReturn(true);
    }

    void assertRejected(ErrorCode code) {
        var error = assertThrows(AppException.class, () -> service.createBooking("customer@test.com", request));
        assertEquals(code, error.getErrorCode());
        verifyNoInteractions(units, bookings);
    }

    @Test
    void savesExactAcceptedTextAndHashEvenWhenFacilityPolicyLaterChanges() {
        when(policies.getForBooking(facility.getId())).thenReturn(policy);
        UUID unitId = UUID.randomUUID();
        StorageUnit unit = StorageUnit.builder().facility(facility).unitType(new UnitType()).build();
        unit.setId(unitId);
        when(units.claimAvailableUnitId(facility.getId(), request.getUnitTypeId())).thenReturn(Optional.of(unitId));
        when(units.findById(unitId)).thenReturn(Optional.of(unit));
        when(pricing.calculateRentalQuote(any())).thenReturn(RentalQuoteResponse.builder()
                .endDate(request.getStartDate().plusMonths(1)).totalRentalFee(BigDecimal.TEN)
                .depositAmount(BigDecimal.ONE).totalExtraFees(BigDecimal.ZERO).initialPaymentAmount(BigDecimal.valueOf(11)).build());
        when(bookings.save(any())).thenAnswer(call -> call.getArgument(0));
        service.createBooking("customer@test.com", request);
        var saved = ArgumentCaptor.forClass(Booking.class);
        verify(bookings).save(saved.capture());
        policy.setTermsAndConditions("Changed terms");
        policy.setProhibitedItems("Changed prohibited items");
        assertEquals("Original terms", saved.getValue().getTermsContentSnapshot());
        assertEquals("Original prohibited items", saved.getValue().getProhibitedItemsSnapshot());
        assertEquals(request.getTermsHash(), saved.getValue().getTermsHash());
        assertNotNull(saved.getValue().getTermsAcceptedAt());
        assertNotEquals(policy.getTermsHash(), saved.getValue().getTermsHash());
    }

    @Test
    void rejectsUnpublishedVersion() {
        when(policies.getForBooking(facility.getId())).thenReturn(policy);
        request.setTermsVersion("invented");
        assertRejected(ErrorCode.TERMS_CHANGED);
    }

    @Test
    void rejectsContentChangedUnderTheSameVersion() {
        policy.setTermsAndConditions("Changed while customer was reading");
        when(policies.getForBooking(facility.getId())).thenReturn(policy);
        assertRejected(ErrorCode.TERMS_CHANGED);
    }

    @Test
    void missingClientVersionCannotUseADefault() {
        when(policies.getForBooking(facility.getId())).thenReturn(policy);
        request.setTermsVersion(null);
        assertRejected(ErrorCode.TERMS_CHANGED);
    }

    @Test
    void missingClientHashCannotUseADefault() {
        when(policies.getForBooking(facility.getId())).thenReturn(policy);
        request.setTermsHash(null);
        assertRejected(ErrorCode.TERMS_CHANGED);
    }

    @Test
    void incompletePublishedTermsBlockBooking() {
        policy.setTermsAndConditions(" ");
        when(policies.getForBooking(facility.getId())).thenReturn(policy);
        assertRejected(ErrorCode.TERMS_NOT_AVAILABLE);
    }

    @Test
    void missingPolicyBlocksBookingInsteadOfInventingAVersion() {
        when(policies.getForBooking(facility.getId())).thenThrow(new AppException(ErrorCode.TERMS_NOT_AVAILABLE));
        assertRejected(ErrorCode.TERMS_NOT_AVAILABLE);
    }

    @Test
    void policyReadFailureIsPropagatedBeforeHoldingInventory() {
        when(policies.getForBooking(facility.getId())).thenThrow(new IllegalStateException("Unavailable"));
        assertThrows(IllegalStateException.class, () -> service.createBooking("customer@test.com", request));
        verifyNoInteractions(units, bookings);
    }
}
