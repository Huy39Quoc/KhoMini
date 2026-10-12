package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.entity.StorageUnit;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.enums.RefundStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.PaymentServiceImpl;
import com.storehub.service.impl.VnpayRefundClient;
import com.storehub.util.VNPayUtil;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class LateCapturedBookingPaymentTest {
    @Mock PaymentRepository payments;
    @Mock BookingRepository bookings;
    @Mock RefundRequestRepository refunds;
    @Mock UserRepository users;
    @Mock EmailService email;
    @Mock ActivityLogService log;
    @Mock PricingService pricing;
    @Mock WaitlistService waitlist;
    @InjectMocks PaymentServiceImpl service;

    @Test
    void successfulIpnAfterCancellationQueuesFullRefundExactlyOnce() {
        Booking booking = booking(BookingStatus.CANCELLED, UnitStatus.AVAILABLE);
        Payment deposit = deposit(booking);
        Payment rent = rent(booking);
        setup(booking, deposit, rent);

        assertEquals(PaymentStatus.REFUND_PENDING,
                service.processVnpayCallback(signedSuccess()).getStatus());
        assertEquals(PaymentStatus.REFUND_PENDING,
                service.processVnpayCallback(signedSuccess()).getStatus());

        assertEquals(BookingStatus.CANCELLED, booking.getStatus());
        assertEquals(UnitStatus.AVAILABLE, booking.getStorageUnit().getStatus());
        assertEquals(new BigDecimal("200"), booking.getDepositPaid());
        assertEquals(PaymentStatus.REFUND_PENDING, rent.getStatus());
        assertEquals("12345678", deposit.getGatewayTransactionNo());

        ArgumentCaptor<RefundRequest> request = ArgumentCaptor.forClass(RefundRequest.class);
        verify(refunds, times(1)).save(request.capture());
        assertEquals(new BigDecimal("1000"), request.getValue().getAmount());
        assertEquals(new BigDecimal("200"), request.getValue().getDepositAmount());
        assertEquals(new BigDecimal("800"), request.getValue().getRentalAmount());
        assertEquals(RefundStatus.QUEUED, request.getValue().getStatus());
        assertNotNull(request.getValue().getRefundPayment());
    }

    @Test
    void successfulIpnAfterExpiryCancelsHeldBookingAndQueuesFullRefund() {
        Booking booking = booking(BookingStatus.PENDING_PAYMENT, UnitStatus.RESERVED);
        booking.setExpiresAt(LocalDateTime.now().minusSeconds(1));
        Payment deposit = deposit(booking);
        setup(booking, deposit, rent(booking));

        assertEquals(PaymentStatus.REFUND_PENDING,
                service.processVnpayCallback(signedSuccess()).getStatus());
        assertEquals(BookingStatus.CANCELLED, booking.getStatus());
        assertEquals(UnitStatus.AVAILABLE, booking.getStorageUnit().getStatus());
        verify(refunds, times(1)).save(any(RefundRequest.class));
    }

    @Test
    void gatewayQueryRecoversChargeAfterFailedReturnAndCancelledBooking() {
        Booking booking = booking(BookingStatus.CANCELLED, UnitStatus.AVAILABLE);
        Payment deposit = deposit(booking);
        Payment rent = rent(booking);
        deposit.setStatus(PaymentStatus.FAILED);
        rent.setStatus(PaymentStatus.FAILED);
        setup(booking, deposit, rent);
        when(payments.findByTransactionId("TXN-1")).thenReturn(Optional.of(deposit));

        assertEquals(PaymentStatus.REFUND_PENDING,
                service.reconcileConfirmedCharge("TXN-1",
                        new VnpayRefundClient.GatewayResult("00", "00", "01", "100000", "12345678"))
                        .getStatus());
        assertEquals(PaymentStatus.REFUND_PENDING, rent.getStatus());
        verify(refunds, times(1)).save(any(RefundRequest.class));
    }

    @Test
    void competingSuccessfulAttemptsConfirmOnlyTheFirstAndRefundTheSecond() {
        Booking booking = booking(BookingStatus.PENDING_PAYMENT, UnitStatus.RESERVED);
        Payment first = deposit(booking);
        setup(booking, first, rent(booking));
        Payment second = Payment.builder().booking(booking).transactionId("TXN-2")
                .paymentType(PaymentType.DEPOSIT).amount(new BigDecimal("200"))
                .gatewayAmount(new BigDecimal("1000")).gatewayCreateDate("20261009230000")
                .status(PaymentStatus.PENDING).build();
        second.setId(UUID.randomUUID());
        Payment secondRent = Payment.builder().booking(booking).transactionId("TXN-2-R")
                .paymentType(PaymentType.RENTAL_FEE).amount(new BigDecimal("800"))
                .status(PaymentStatus.PENDING).build();
        when(payments.findBookingIdByTransactionId("TXN-2")).thenReturn(Optional.of(booking.getId()));
        when(payments.lockByTransactionId("TXN-2")).thenReturn(Optional.of(second));
        when(payments.findByTransactionId("TXN-2-R")).thenReturn(Optional.of(secondRent));

        assertEquals(PaymentStatus.PAID, service.processVnpayCallback(signedSuccess()).getStatus());
        assertEquals(PaymentStatus.REFUND_PENDING,
                service.processVnpayCallback(signedSuccess("TXN-2")).getStatus());
        assertEquals(BookingStatus.CONFIRMED, booking.getStatus());
        assertEquals(PaymentStatus.REFUND_PENDING, secondRent.getStatus());
        verify(refunds, times(1)).save(any(RefundRequest.class));
    }

    private Booking booking(BookingStatus status, UnitStatus unitStatus) {
        Booking booking = Booking.builder().bookingCode("BK-1").status(status)
                .depositPaid(BigDecimal.ZERO)
                .storageUnit(StorageUnit.builder().status(unitStatus).build())
                .build();
        booking.setId(UUID.randomUUID());
        return booking;
    }

    private Payment deposit(Booking booking) {
        Payment payment = Payment.builder().booking(booking).transactionId("TXN-1")
                .paymentType(PaymentType.DEPOSIT).amount(new BigDecimal("200"))
                .gatewayAmount(new BigDecimal("1000"))
                .gatewayCreateDate("20261009230000")
                .status(PaymentStatus.PENDING).build();
        payment.setId(UUID.randomUUID());
        return payment;
    }

    private Payment rent(Booking booking) {
        Payment payment = Payment.builder().booking(booking).transactionId("TXN-1-R")
                .paymentType(PaymentType.RENTAL_FEE).amount(new BigDecimal("800"))
                .status(PaymentStatus.PENDING).build();
        payment.setId(UUID.randomUUID());
        return payment;
    }

    private void setup(Booking booking, Payment deposit, Payment rent) {
        ReflectionTestUtils.setField(service, "vnpHashSecret", "test-secret");
        when(payments.findBookingIdByTransactionId("TXN-1"))
                .thenReturn(Optional.of(booking.getId()));
        when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
        when(payments.lockByTransactionId("TXN-1")).thenReturn(Optional.of(deposit));
        when(payments.findByTransactionId("TXN-1-R")).thenReturn(Optional.of(rent));
        when(payments.save(any(Payment.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));
    }

    private Map<String, String> signedSuccess() {
        return signedSuccess("TXN-1");
    }

    private Map<String, String> signedSuccess(String transactionId) {
        Map<String, String> params = new HashMap<>();
        params.put("vnp_Amount", "100000");
        params.put("vnp_ResponseCode", "00");
        params.put("vnp_TransactionNo", "12345678");
        params.put("vnp_TransactionStatus", "00");
        params.put("vnp_TxnRef", transactionId);
        params.put("vnp_SecureHash", VNPayUtil.hmacSHA512("test-secret",
                "vnp_Amount=100000&vnp_ResponseCode=00&vnp_TransactionNo=12345678"
                        + "&vnp_TransactionStatus=00&vnp_TxnRef=" + transactionId));
        return params;
    }
}
