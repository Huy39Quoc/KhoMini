package com.storehub.service;

import com.storehub.dto.request.ResetPinRequest;
import com.storehub.dto.request.SetupPinRequest;
import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.SmartAccessResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.mapper.CustomerStorageMapper;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.CustomerStorageServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CustomerSmartKeyPinTest {

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

    private UUID customerId;
    private UUID bookingId;
    private User customer;
    private Booking booking;

    @BeforeEach
    void setUp() {
        customerId = UUID.randomUUID();
        bookingId = UUID.randomUUID();
        customer = new User();
        customer.setId(customerId);
        customer.setEmail("customer@test.com");
        customer.setPassword("hashed-user-pass");

        booking = Booking.builder()
                .status(BookingStatus.ACTIVE)
                .bookingCode("BK-1001")
                .unitLocked(true)
                .build();
        booking.setId(bookingId);

        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(bookingId, customerId)).thenReturn(Optional.of(booking));
        when(mapper.toSmartAccessResponse(any(Booking.class))).thenReturn(new SmartAccessResponse());
        when(encoder.encode(anyString())).thenAnswer(invocation -> "hash:" + invocation.getArgument(0));
    }

    @Test
    void setupPin_withSystemGenerated_generatesAndReturnsPin() {
        SetupPinRequest req = new SetupPinRequest(null);
        SmartAccessResponse res = storage.setupPin(bookingId, "customer@test.com", req);

        assertNotNull(res.getGeneratedPin());
        assertEquals(6, res.getGeneratedPin().length());
        assertNotNull(booking.getAccessPin());
        assertTrue(booking.getAccessPin().startsWith("hash:"));
        verify(bookings).save(booking);
    }

    @Test
    void setupPin_withCustomPin_storesCustomPinWithoutReturningIt() {
        SetupPinRequest req = new SetupPinRequest("654321");
        SmartAccessResponse res = storage.setupPin(bookingId, "customer@test.com", req);

        assertNull(res.getGeneratedPin());
        assertEquals("hash:654321", booking.getAccessPin());
        verify(bookings).save(booking);
    }

    @Test
    void updatePin_withSystemGenerated_verifiesOldPinAndGeneratesNewPin() {
        booking.setAccessPin("hash:111111");
        when(encoder.matches("111111", "hash:111111")).thenReturn(true);

        UpdatePinRequest req = new UpdatePinRequest("111111", null);
        SmartAccessResponse res = storage.updateAccessPin(bookingId, "customer@test.com", req);

        assertNotNull(res.getGeneratedPin());
        assertEquals(6, res.getGeneratedPin().length());
        assertTrue(booking.getAccessPin().startsWith("hash:"));
        verify(bookings).save(booking);
    }

    @Test
    void updatePin_withCustomPin_verifiesOldPinAndStoresCustomPin() {
        booking.setAccessPin("hash:111111");
        when(encoder.matches("111111", "hash:111111")).thenReturn(true);

        UpdatePinRequest req = new UpdatePinRequest("111111", "999888");
        SmartAccessResponse res = storage.updateAccessPin(bookingId, "customer@test.com", req);

        assertNull(res.getGeneratedPin());
        assertEquals("hash:999888", booking.getAccessPin());
        verify(bookings).save(booking);
    }

    @Test
    void resetPin_withSystemGenerated_verifiesPasswordAndGeneratesNewPin() {
        booking.setAccessPin("hash:oldpin");
        when(encoder.matches("MySecurePass123", "hashed-user-pass")).thenReturn(true);

        ResetPinRequest req = new ResetPinRequest("MySecurePass123", null);
        SmartAccessResponse res = storage.resetPin(bookingId, "customer@test.com", req);

        assertNotNull(res.getGeneratedPin());
        assertEquals(6, res.getGeneratedPin().length());
        assertTrue(booking.getAccessPin().startsWith("hash:"));
        verify(bookings).save(booking);
    }

    @Test
    void resetPin_withCustomPin_verifiesPasswordAndStoresCustomPin() {
        booking.setAccessPin("hash:oldpin");
        when(encoder.matches("MySecurePass123", "hashed-user-pass")).thenReturn(true);

        ResetPinRequest req = new ResetPinRequest("MySecurePass123", "123123");
        SmartAccessResponse res = storage.resetPin(bookingId, "customer@test.com", req);

        assertNull(res.getGeneratedPin());
        assertEquals("hash:123123", booking.getAccessPin());
        verify(bookings).save(booking);
    }
}
