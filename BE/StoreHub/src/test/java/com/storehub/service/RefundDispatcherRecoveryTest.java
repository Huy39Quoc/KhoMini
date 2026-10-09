package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.enums.RefundStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.scheduler.RefundDispatcher;
import com.storehub.service.impl.VnpayRefundClient;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RefundDispatcherRecoveryTest {
    @Mock RefundRequestRepository refunds;
    @Mock PaymentRepository payments;
    @Mock BookingRepository bookings;
    @Mock ActivityLogService activityLog;
    @Mock VnpayRefundClient gateway;
    @Mock PlatformTransactionManager transactionManager;

    @Test
    void staleSendingRequestIsQueriedWithoutIssuingAnotherRefund() throws Exception {
        UUID id = UUID.randomUUID();
        Booking booking = Booking.builder().bookingCode("BK-1").build();
        Payment original = Payment.builder().transactionId("TXN-1")
                .gatewayCreateDate("20261009123456")
                .gatewayAmount(new BigDecimal("1000000")).build();
        RefundRequest request = RefundRequest.builder().booking(booking)
                .originalPayment(original).requestId("REFUND1")
                .amount(new BigDecimal("200000"))
                .status(RefundStatus.SENDING)
                .updatedStatusAt(LocalDateTime.now().minusMinutes(10)).build();
        request.setId(id);
        when(refunds.findTop20ByStatusInAndUpdatedStatusAtBeforeOrderByUpdatedStatusAtAsc(
                any(), any())).thenReturn(List.of(request));
        when(refunds.findById(id)).thenReturn(Optional.of(request));
        when(refunds.lockById(id)).thenReturn(Optional.of(request));
        when(transactionManager.getTransaction(any())).thenAnswer(invocation -> new SimpleTransactionStatus());
        when(gateway.query("TXN-1", "20261009123456"))
                .thenReturn(new VnpayRefundClient.GatewayResult("00", "05", "03", "20000000"));

        new RefundDispatcher(refunds, payments, bookings, activityLog, gateway, transactionManager)
                .dispatch();

        assertEquals(RefundStatus.AWAITING_CONFIRMATION, request.getStatus());
        verify(gateway, never()).refund(any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void fullRefundSettlesItsOriginalEvenWhenBookingHasAnotherDeposit() throws Exception {
        UUID id = UUID.randomUUID();
        Booking booking = Booking.builder().bookingCode("BK-1")
                .depositPaid(new BigDecimal("400")).build();
        booking.setId(UUID.randomUUID());
        Payment original = Payment.builder().transactionId("TXN-2")
                .amount(new BigDecimal("200"))
                .gatewayCreateDate("20261009230000")
                .gatewayAmount(new BigDecimal("1000"))
                .status(PaymentStatus.REFUND_PENDING).build();
        Payment rent = Payment.builder().transactionId("TXN-2-R")
                .amount(new BigDecimal("800"))
                .status(PaymentStatus.REFUND_PENDING).build();
        Payment refundPayment = Payment.builder().amount(new BigDecimal("1000"))
                .status(PaymentStatus.REFUND_PENDING).build();
        RefundRequest request = RefundRequest.builder().booking(booking)
                .originalPayment(original).refundPayment(refundPayment)
                .requestId("REFUND2").amount(new BigDecimal("1000"))
                .depositAmount(new BigDecimal("200"))
                .rentalAmount(new BigDecimal("800"))
                .status(RefundStatus.SENDING)
                .updatedStatusAt(LocalDateTime.now().minusMinutes(10)).build();
        request.setId(id);
        when(refunds.findById(id)).thenReturn(Optional.of(request));
        when(refunds.lockById(id)).thenReturn(Optional.of(request));
        when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
        when(payments.findByTransactionId("TXN-2-R")).thenReturn(Optional.of(rent));
        when(transactionManager.getTransaction(any()))
                .thenAnswer(invocation -> new SimpleTransactionStatus());
        when(gateway.query("TXN-2", "20261009230000"))
                .thenReturn(new VnpayRefundClient.GatewayResult("00", "00", "02", "100000"));

        new RefundDispatcher(refunds, payments, bookings, activityLog, gateway, transactionManager)
                .reconcile(id);

        assertEquals(RefundStatus.COMPLETED, request.getStatus());
        assertEquals(PaymentStatus.REFUNDED, original.getStatus());
        assertEquals(PaymentStatus.REFUNDED, rent.getStatus());
        assertEquals(PaymentStatus.REFUNDED, refundPayment.getStatus());
        assertEquals(new BigDecimal("200"), booking.getDepositPaid());
    }

    @Test
    void cancelledExtensionRefundDoesNotSubtractTheBookingDeposit() throws Exception {
        UUID id = UUID.randomUUID();
        Booking booking = Booking.builder().bookingCode("BK-EXT")
                .depositPaid(new BigDecimal("200")).build();
        booking.setId(UUID.randomUUID());
        Payment original = Payment.builder().transactionId("TXN-EXT")
                .paymentType(PaymentType.EXTRA_CHARGE).amount(new BigDecimal("1000"))
                .gatewayAmount(new BigDecimal("1000"))
                .gatewayCreateDate("20261009230000").status(PaymentStatus.REFUND_PENDING).build();
        Payment refundPayment = Payment.builder().status(PaymentStatus.REFUND_PENDING).build();
        RefundRequest request = RefundRequest.builder().booking(booking)
                .originalPayment(original).refundPayment(refundPayment).requestId("REFUND-EXT")
                .amount(new BigDecimal("1000")).depositAmount(BigDecimal.ZERO)
                .rentalAmount(new BigDecimal("1000")).status(RefundStatus.SENDING).build();
        request.setId(id);
        when(refunds.findById(id)).thenReturn(Optional.of(request));
        when(refunds.lockById(id)).thenReturn(Optional.of(request));
        when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
        when(transactionManager.getTransaction(any()))
                .thenAnswer(invocation -> new SimpleTransactionStatus());
        when(gateway.query("TXN-EXT", "20261009230000"))
                .thenReturn(new VnpayRefundClient.GatewayResult("00", "00", "02", "100000"));

        new RefundDispatcher(refunds, payments, bookings, activityLog, gateway, transactionManager)
                .reconcile(id);

        assertEquals(RefundStatus.COMPLETED, request.getStatus());
        assertEquals(PaymentStatus.REFUNDED, original.getStatus());
        assertEquals(PaymentStatus.REFUNDED, refundPayment.getStatus());
        assertEquals(new BigDecimal("200"), booking.getDepositPaid());
        verify(payments, never()).findByTransactionId(any());
    }
}
