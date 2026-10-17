package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.Payment;
import com.storehub.entity.Role;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.User;
import com.storehub.exception.AppException;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.PaymentServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PaymentHistoryAccessTest {
    @Mock PaymentRepository paymentRepository;
    @Mock UserRepository userRepository;
    @Mock BookingRepository bookingRepository;
    @Mock EmailService emailService;
    @Mock ActivityLogService activityLogService;
    @Mock PricingService pricingService;
    @Mock FacilityPolicyRepository facilityPolicies;
    @InjectMocks PaymentServiceImpl paymentService;

    @Test
    void staffCannotListPaymentsFromAnotherFacility() {
        UUID assignedId = UUID.randomUUID();
        UUID requestedId = UUID.randomUUID();
        when(userRepository.findByEmail("staff@test.com"))
                .thenReturn(Optional.of(viewer("STAFF", assignedId)));

        PageRequest page = PageRequest.of(0, 20);
        assertThrows(AppException.class, () -> paymentService
                .getFacilityPaymentHistory("staff@test.com", requestedId, page));
        verify(paymentRepository, never()).findFacilityPayments(requestedId, page);
    }

    @Test
    void managerCanListPaymentsFromAssignedFacility() {
        UUID assignedId = UUID.randomUUID();
        when(userRepository.findByEmail("manager@test.com"))
                .thenReturn(Optional.of(viewer("FACILITY_MANAGER", assignedId)));
        PageRequest page = PageRequest.of(0, 20);
        when(paymentRepository.findFacilityPayments(assignedId, page)).thenReturn(Page.empty(page));

        paymentService.getFacilityPaymentHistory("manager@test.com", assignedId, page);
        verify(paymentRepository).findFacilityPayments(assignedId, page);
    }

    @Test
    void staffCannotReadPaymentDetailFromAnotherFacility() {
        UUID paymentId = UUID.randomUUID();
        Facility other = new Facility();
        other.setId(UUID.randomUUID());
        StorageUnit unit = StorageUnit.builder().facility(other).build();
        Booking booking = Booking.builder().storageUnit(unit).build();
        Payment payment = Payment.builder().booking(booking).build();
        when(paymentRepository.findById(paymentId)).thenReturn(Optional.of(payment));
        when(userRepository.findByEmail("staff@test.com"))
                .thenReturn(Optional.of(viewer("STAFF", UUID.randomUUID())));

        assertThrows(AppException.class, () -> paymentService
                .getPaymentDetail(paymentId, "staff@test.com"));
    }

    private User viewer(String roleName, UUID facilityId) {
        Facility facility = new Facility();
        facility.setId(facilityId);
        return User.builder().role(Role.builder().name(roleName).build())
                .facility(facility).build();
    }
}
