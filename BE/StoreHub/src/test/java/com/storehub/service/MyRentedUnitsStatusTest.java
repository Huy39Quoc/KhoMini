package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.User;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.enums.BookingStatus;
import com.storehub.mapper.CustomerStorageMapper;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.CustomerStorageServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;

@ExtendWith(MockitoExtension.class)
class MyRentedUnitsStatusTest {
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock PaymentRepository payments;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock FacilityPolicyService policies;
    @Mock PaymentService paymentService;
    @Mock CustomerStorageMapper mapper;
    @Mock PasswordEncoder encoder;
    @InjectMocks CustomerStorageServiceImpl storage;

    @Test
    void rentedUnitsAndAwaitingHandoverUseSeparateStatuses() {
        UUID customerId = UUID.randomUUID();
        User customer = new User(); customer.setId(customerId);
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.findActiveBookingsByCustomerId(customerId, List.of(BookingStatus.ACTIVE)))
                .thenReturn(List.of(new Booking()));
        when(bookings.findActiveBookingsByCustomerId(customerId, List.of(BookingStatus.CONFIRMED)))
                .thenReturn(List.of(new Booking()));
        when(mapper.toMyUnitResponse(any(Booking.class)))
                .thenReturn(MyUnitResponse.builder().build());

        assertEquals(1, storage.getMyRentedUnits("customer@test.com").size());
        assertEquals(1, storage.getAwaitingHandover("customer@test.com").size());
        verify(bookings).findActiveBookingsByCustomerId(customerId, List.of(BookingStatus.ACTIVE));
        verify(bookings).findActiveBookingsByCustomerId(customerId, List.of(BookingStatus.CONFIRMED));
    }
}
