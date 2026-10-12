package com.storehub.service;

import com.storehub.entity.Payment;
import com.storehub.entity.Booking;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.PaymentServiceImpl;
import com.storehub.util.VNPayUtil;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import org.mockito.ArgumentCaptor;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;

@ExtendWith(MockitoExtension.class)
class PaymentCallbackStatusTest {
    @Mock PaymentRepository payments;
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock EmailService email;
    @Mock ActivityLogService activityLog;
    @Mock PricingService pricing;
    @Mock RefundRequestRepository refunds;
    @Mock WaitlistService waitlist;
    @InjectMocks PaymentServiceImpl service;

    @Test
    void responseCodeSuccessWithFailedTransactionDoesNotMarkPaymentPaid() {
        Payment payment = pendingPayment();
        ReflectionTestUtils.setField(service, "vnpHashSecret", "test-secret");
        when(payments.lockByTransactionId("TXN-1")).thenReturn(Optional.of(payment));

        assertEquals(PaymentStatus.FAILED,
                service.processVnpayCallback(signedCallback("02")).getStatus());
        assertEquals(PaymentStatus.FAILED, payment.getStatus());
        verify(bookings, never()).save(any());
    }

    @Test
    void unfinishedTransactionRemainsPendingForLaterIpn() {
        Payment payment = pendingPayment();
        ReflectionTestUtils.setField(service, "vnpHashSecret", "test-secret");
        when(payments.findByTransactionId("TXN-1")).thenReturn(Optional.of(payment));

        assertEquals(PaymentStatus.PENDING,
                service.processVnpayCallback(signedCallback("01")).getStatus());
        assertEquals(PaymentStatus.PENDING, payment.getStatus());
        verify(payments, never()).save(any());
    }

    @Test
    void failedLateFeeCreatesPayableReplacementAndVoidsOldReference() {
        Payment payment = pendingPayment();
        payment.setNote(OVERDUE_LATE_FEE);
        payment.setBooking(Booking.builder().build());
        payment.setPaymentTime(java.time.LocalDateTime.now());
        ReflectionTestUtils.setField(service, "vnpHashSecret", "test-secret");
        when(payments.lockByTransactionId("TXN-1")).thenReturn(Optional.of(payment));

        service.processVnpayCallback(signedCallback("02"));

        ArgumentCaptor<Payment> saved = ArgumentCaptor.forClass(Payment.class);
        verify(payments, times(3)).save(saved.capture());
        Payment retry = saved.getAllValues().get(2);
        assertEquals(PaymentStatus.FAILED, payment.getStatus());
        assertNotNull(payment.getVoidedAt());
        assertEquals(PaymentStatus.PENDING, retry.getStatus());
        assertEquals(payment.getAmount(), retry.getAmount());
        assertEquals(OVERDUE_LATE_FEE, retry.getNote());
        assertNotEquals(payment.getTransactionId(), retry.getTransactionId());
    }

    @Test
    void lateCaptureOfFailedFeeIsRefundedInsteadOfChargingTwice() {
        UUID bookingId = UUID.randomUUID();
        Booking booking = Booking.builder().build(); booking.setId(bookingId);
        Payment payment = pendingPayment();
        payment.setId(UUID.randomUUID());
        payment.setBooking(booking);
        payment.setNote(OVERDUE_LATE_FEE);
        payment.setPaymentTime(java.time.LocalDateTime.now());
        payment.setGatewayAmount(new BigDecimal("1000"));
        payment.setGatewayCreateDate("20261012100000");
        ReflectionTestUtils.setField(service, "vnpHashSecret", "test-secret");
        when(payments.lockByTransactionId("TXN-1")).thenReturn(Optional.of(payment));
        when(payments.findBookingIdByTransactionId("TXN-1"))
                .thenReturn(Optional.of(bookingId));
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));
        when(payments.save(any(Payment.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        service.processVnpayCallback(signedCallback("02"));
        assertEquals(PaymentStatus.REFUND_PENDING,
                service.processVnpayCallback(signedCallback("00")).getStatus());
        verify(refunds, atLeastOnce()).save(any());
    }

    private Payment pendingPayment() {
        return Payment.builder().transactionId("TXN-1")
                .paymentType(PaymentType.EXTRA_CHARGE).amount(new BigDecimal("1000"))
                .status(PaymentStatus.PENDING).build();
    }

    private Map<String, String> signedCallback(String transactionStatus) {
        Map<String, String> callback = new HashMap<>();
        callback.put("vnp_Amount", "100000");
        callback.put("vnp_ResponseCode", "00");
        callback.put("vnp_TransactionStatus", transactionStatus);
        callback.put("vnp_TxnRef", "TXN-1");
        String hashData = "vnp_Amount=100000&vnp_ResponseCode=00&vnp_TransactionStatus="
                + transactionStatus + "&vnp_TxnRef=TXN-1";
        callback.put("vnp_SecureHash", VNPayUtil.hmacSHA512("test-secret", hashData));
        return callback;
    }
}
