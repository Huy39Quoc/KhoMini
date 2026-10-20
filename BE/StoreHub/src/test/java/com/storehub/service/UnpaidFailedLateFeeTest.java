package com.storehub.service;

import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.CustomerStorageServiceImpl;
import com.storehub.service.impl.PaymentServiceImpl;
import com.storehub.scheduler.OverdueScheduler;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;

@ExtendWith(MockitoExtension.class)
class UnpaidFailedLateFeeTest {
    @Mock BookingRepository bookings;
    @Mock PaymentRepository payments;
    @Mock UserRepository users;
    @Mock OverdueScheduler overdueScheduler;
    @InjectMocks CustomerStorageServiceImpl storage;
    @Mock FacilityPolicyRepository facilityPolicies;
    @InjectMocks PaymentServiceImpl paymentService;

    @Test
    void failedFeeBlocksExtensionAndReturn() {
        UUID bookingId = UUID.randomUUID(), customerId = UUID.randomUUID();
        User customer = new User(); customer.setId(customerId);
        Booking booking = Booking.builder().status(BookingStatus.ACTIVE).build();
        booking.setId(bookingId);
        Payment failed = Payment.builder().booking(booking).paymentType(PaymentType.EXTRA_CHARGE)
                .status(PaymentStatus.FAILED).note(OVERDUE_LATE_FEE)
                .amount(new BigDecimal("100")).build();
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(bookingId, customerId))
                .thenReturn(Optional.of(booking));
        when(overdueScheduler.accrueOutstandingForCheckout(eq(booking), any()))
                .thenReturn(true);
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                bookingId, PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                List.of(PaymentStatus.PENDING, PaymentStatus.FAILED)))
                .thenReturn(List.of(failed));

        AppException extension = assertThrows(AppException.class,
                () -> storage.extendRental(bookingId, "customer@test.com", new ExtendRentalRequest()));
        assertEquals(ErrorCode.OVERDUE_FEE_UNPAID, extension.getErrorCode());
        AppException checkout = assertThrows(AppException.class,
                () -> paymentService.refundDepositOnReturn(booking));
        assertEquals(ErrorCode.OVERDUE_FEE_UNPAID_ON_RETURN, checkout.getErrorCode());
    }
}
