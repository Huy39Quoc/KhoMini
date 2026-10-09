package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.UserRepository;
import com.storehub.mapper.CustomerStorageMapper;
import com.storehub.service.impl.CustomerStorageServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static com.storehub.common.PaymentNotes.RENTAL_EXTENSION;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CancelledExtensionAttemptTest {
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock PaymentRepository payments;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock FacilityPolicyService policies;
    @Mock PaymentService paymentService;
    @Mock CustomerStorageMapper mapper;
    @Mock PasswordEncoder encoder;
    @InjectMocks CustomerStorageServiceImpl service;

    @Test
    void cancellingRequestVoidsPreviouslyFailedAttemptBeforeAnotherRequestCanBeCreated() {
        User customer = User.builder().email("customer@example.com").build();
        customer.setId(UUID.randomUUID());
        Booking booking = Booking.builder().status(BookingStatus.ACTIVE)
                .bookingCode("BK-1").endDate(LocalDate.of(2026, 12, 1))
                .rentalMonths(2).totalRentalFee(new BigDecimal("800"))
                .pendingExtraMonths(1).pendingExtensionFee(new BigDecimal("100"))
                .build();
        booking.setId(UUID.randomUUID());
        Payment failed = Payment.builder().booking(booking)
                .paymentType(PaymentType.EXTRA_CHARGE).note(RENTAL_EXTENSION)
                .status(PaymentStatus.FAILED).amount(new BigDecimal("100")).build();
        when(users.findByEmail(customer.getEmail())).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(booking.getId(), customer.getId()))
                .thenReturn(Optional.of(booking));
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                booking.getId(), PaymentType.EXTRA_CHARGE, RENTAL_EXTENSION,
                List.of(PaymentStatus.PENDING, PaymentStatus.FAILED)))
                .thenReturn(List.of(failed));

        service.cancelPendingExtension(booking.getId(), customer.getEmail());

        assertEquals(PaymentStatus.FAILED, failed.getStatus());
        assertNotNull(failed.getVoidedAt());
        assertNull(booking.getPendingExtraMonths());
    }
}
