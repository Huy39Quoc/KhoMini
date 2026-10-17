package com.storehub.service;

import com.storehub.dto.request.UnlockRequest;
import com.storehub.entity.Booking;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
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

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CustomerPinLockoutTest {
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock PaymentRepository paymentRepository;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock FacilityPolicyService policies;
    @Mock PaymentService payments;
    @Mock CustomerStorageMapper mapper;
    @Mock PasswordEncoder encoder;
    @InjectMocks CustomerStorageServiceImpl storage;

    @Test
    void failedPinAttemptsUseTheLockedBookingAndBlockTheFifthAttempt() {
        UUID bookingId = UUID.randomUUID();
        UUID customerId = UUID.randomUUID();
        User customer = new User();
        customer.setId(customerId);
        Booking booking = Booking.builder().status(BookingStatus.ACTIVE)
                .accessPin("stored-hash").pinFailedAttempts(0).build();
        booking.setId(bookingId);
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(bookingId, customerId))
                .thenReturn(Optional.of(booking));
        UnlockRequest request = new UnlockRequest("123456");

        for (int attempt = 1; attempt <= 5; attempt++) {
            AppException exception = assertThrows(AppException.class,
                    () -> storage.unlockWithPin(bookingId, "customer@test.com", request));
            assertEquals(attempt == 5
                    ? ErrorCode.PIN_TEMPORARILY_LOCKED
                    : ErrorCode.PIN_INCORRECT, exception.getErrorCode());
        }

        assertNotNull(booking.getPinLockedUntil());
        verify(bookings, times(5)).lockByIdAndCustomerId(bookingId, customerId);
        verify(bookings, times(5)).save(booking);
    }
}
