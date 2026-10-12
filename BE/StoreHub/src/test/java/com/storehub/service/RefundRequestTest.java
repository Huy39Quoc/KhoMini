package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.enums.RefundStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.PaymentServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RefundRequestTest {
    @Mock PaymentRepository payments;
    @Mock RefundRequestRepository refunds;
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock EmailService email;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock WaitlistService waitlist;
    @InjectMocks PaymentServiceImpl service;

    @Test
    void returnQueuesGatewayRefundWithoutPrematurelyMarkingItRefunded() {
        Booking booking = Booking.builder().bookingCode("BK-1")
                .depositPaid(new BigDecimal("200000")).build();
        booking.setId(UUID.randomUUID());
        Payment paid = Payment.builder().booking(booking).paymentType(PaymentType.DEPOSIT)
                .transactionId("TXN-1").amount(new BigDecimal("200000"))
                .gatewayCreateDate("20261009123456")
                .gatewayAmount(new BigDecimal("1000000"))
                .status(PaymentStatus.PAID).build();
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID))
                .thenReturn(Optional.of(paid));
        when(payments.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        assertEquals(new BigDecimal("200000"), service.refundDepositOnReturn(booking));
        assertEquals(new BigDecimal("200000"), booking.getDepositPaid());
        assertEquals(PaymentStatus.PAID, paid.getStatus());
        ArgumentCaptor<RefundRequest> captor = ArgumentCaptor.forClass(RefundRequest.class);
        verify(refunds).save(captor.capture());
        assertEquals(RefundStatus.QUEUED, captor.getValue().getStatus());
        assertEquals(PaymentStatus.REFUND_PENDING,
                captor.getValue().getRefundPayment().getStatus());
    }

    @Test
    void legacyPaymentWithoutGatewayDateRequiresManualReconciliation() {
        Booking booking = Booking.builder().depositPaid(new BigDecimal("100"))
                .bookingCode("BK-OLD").build();
        booking.setId(UUID.randomUUID());
        Payment old = Payment.builder().booking(booking)
                .paymentType(PaymentType.DEPOSIT).status(PaymentStatus.PAID)
                .transactionId("TXN-OLD").build();
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID))
                .thenReturn(Optional.of(old));
        when(payments.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.refundDeposit(booking, new BigDecimal("100"));

        ArgumentCaptor<RefundRequest> captor = ArgumentCaptor.forClass(RefundRequest.class);
        verify(refunds).save(captor.capture());
        assertEquals(RefundStatus.MISSING_METADATA, captor.getValue().getStatus());
    }
}
