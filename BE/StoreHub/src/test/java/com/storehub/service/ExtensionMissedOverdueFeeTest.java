package com.storehub.service;

import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.exception.OutstandingOverdueExtensionException;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.scheduler.OverdueScheduler;
import com.storehub.service.impl.CustomerStorageServiceImpl;
import com.storehub.service.impl.PaymentServiceImpl;
import com.storehub.util.VNPayUtil;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import static com.storehub.common.PaymentNotes.RENTAL_EXTENSION;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ExtensionMissedOverdueFeeTest {
    @Mock BookingRepository bookings;
    @Mock PaymentRepository payments;
    @Mock RefundRequestRepository refunds;
    @Mock UserRepository users;
    @Mock OverdueScheduler overdueScheduler;
    @Mock PaymentService paymentService;
    @InjectMocks CustomerStorageServiceImpl storage;
    @InjectMocks PaymentServiceImpl paymentCallback;

    @Test
    void newlyAccruedDebtIsCommittedWhenExtensionIsRefused() throws Exception {
        User customer = new User(); customer.setId(UUID.randomUUID());
        Booking booking = Booking.builder().status(BookingStatus.ACTIVE)
                .endDate(LocalDate.now().minusDays(3)).build();
        booking.setId(UUID.randomUUID());
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(booking.getId(), customer.getId()))
                .thenReturn(Optional.of(booking));
        when(overdueScheduler.accrueOutstandingForCheckout(eq(booking), any())).thenReturn(true);

        AppException error = assertThrows(AppException.class,
                () -> storage.extendRental(booking.getId(), "customer@test.com",
                        new ExtendRentalRequest()));
        assertEquals(ErrorCode.OVERDUE_FEE_UNPAID, error.getErrorCode());
        verifyNoInteractions(paymentService);

        var method = CustomerStorageServiceImpl.class.getMethod("extendRental",
                UUID.class, String.class, ExtendRentalRequest.class);
        var transaction = new AnnotationTransactionAttributeSource()
                .getTransactionAttribute(method, CustomerStorageServiceImpl.class);
        assertNotNull(transaction);
        assertFalse(transaction.rollbackOn(new OutstandingOverdueExtensionException()));
        assertTrue(transaction.rollbackOn(new AppException(ErrorCode.INVALID_REQUEST)));
    }

    @Test
    void lateCapturedExtensionIsRefundedAndDoesNotMoveEndDate() {
        Booking booking = Booking.builder().bookingCode("BK-LATE-EXT")
                .status(BookingStatus.ACTIVE).endDate(LocalDate.now().minusDays(3))
                .rentalMonths(2).totalRentalFee(new BigDecimal("800"))
                .pendingExtraMonths(1).pendingExtensionFee(new BigDecimal("300"))
                .build();
        booking.setId(UUID.randomUUID());
        Payment captured = Payment.builder().booking(booking).transactionId("TXN-EXT")
                .paymentType(PaymentType.EXTRA_CHARGE).note(RENTAL_EXTENSION)
                .status(PaymentStatus.PENDING).amount(new BigDecimal("300"))
                .gatewayAmount(new BigDecimal("300"))
                .gatewayCreateDate("20261019000000").build();
        captured.setId(UUID.randomUUID());
        when(payments.findBookingIdByTransactionId("TXN-EXT"))
                .thenReturn(Optional.of(booking.getId()));
        when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
        when(payments.lockByTransactionId("TXN-EXT"))
                .thenReturn(Optional.of(captured));
        when(overdueScheduler.accrueOutstandingForCheckout(eq(booking), any())).thenReturn(true);
        when(payments.save(any(Payment.class))).thenAnswer(call -> call.getArgument(0));
        ReflectionTestUtils.setField(paymentCallback, "vnpHashSecret", "test-secret");

        Map<String, String> params = new HashMap<>();
        params.put("vnp_Amount", "30000");
        params.put("vnp_ResponseCode", "00");
        params.put("vnp_TransactionStatus", "00");
        params.put("vnp_TxnRef", "TXN-EXT");
        params.put("vnp_SecureHash", VNPayUtil.hmacSHA512("test-secret",
                "vnp_Amount=30000&vnp_ResponseCode=00&vnp_TransactionStatus=00&vnp_TxnRef=TXN-EXT"));

        assertEquals(PaymentStatus.REFUND_PENDING,
                paymentCallback.processVnpayCallback(params).getStatus());
        assertEquals(LocalDate.now().minusDays(3), booking.getEndDate());
        assertNull(booking.getPendingExtraMonths());
        assertNull(booking.getPendingExtensionFee());
        assertEquals(new BigDecimal("800"), booking.getTotalRentalFee());
        verify(refunds).save(any(RefundRequest.class));
    }

    @Test
    void retryingAnOldExtensionLinkCannotIssueANewLinkBeforeTheLateFeeIsPaid() {
        User customer = new User(); customer.setId(UUID.randomUUID());
        Booking booking = Booking.builder().status(BookingStatus.ACTIVE)
                .endDate(LocalDate.now().minusDays(3)).pendingExtraMonths(1).build();
        booking.setId(UUID.randomUUID());
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(booking.getId(), customer.getId()))
                .thenReturn(Optional.of(booking));
        when(overdueScheduler.accrueOutstandingForCheckout(eq(booking), any()))
                .thenReturn(true);

        AppException error = assertThrows(AppException.class,
                () -> paymentCallback.getPendingExtensionPayment(
                        "customer@test.com", booking.getId()));
        assertEquals(ErrorCode.OVERDUE_FEE_UNPAID, error.getErrorCode());
        verify(payments, never())
                .findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                        any(), any(), any(), any());
    }

    @Test
    void futureEndDateDoesNotEraseUnpaidLateFeeSnapshot() {
        Booking booking = Booking.builder().status(BookingStatus.ACTIVE)
                .endDate(LocalDate.now().plusMonths(1))
                .overdueDetectedAt(LocalDateTime.now().minusDays(1))
                .overdueFeeAccrued(new BigDecimal("150")).build();
        booking.setId(UUID.randomUUID());
        Payment debt = Payment.builder().status(PaymentStatus.PENDING)
                .amount(new BigDecimal("150")).build();
        when(payments.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                booking.getId(), PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                List.of(PaymentStatus.PENDING, PaymentStatus.FAILED)))
                .thenReturn(List.of(debt));

        ReflectionTestUtils.invokeMethod(storage, "reconcileOverdueState", booking);

        assertEquals(new BigDecimal("150"), booking.getOverdueFeeAccrued());
        assertNotNull(booking.getOverdueDetectedAt());
        verify(bookings, never()).save(booking);
    }
}
