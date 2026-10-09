package com.storehub.service;

import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.UnitType;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.exception.AppException;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.PaymentServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PaymentInitiationRetryTest {
    @Mock PaymentRepository payments;
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock EmailService email;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock RefundRequestRepository refunds;
    @InjectMocks PaymentServiceImpl service;

    @Test
    void repeatedInitiationReturnsSameLiveUrlWithoutFailingOriginalTransaction() {
        Booking booking = booking();
        Payment deposit = deposit(booking, LocalDateTime.now(ZoneId.of("Asia/Ho_Chi_Minh"))
                .minusMinutes(1));
        Payment rent = Payment.builder().transactionId("TXN-1-R")
                .paymentType(PaymentType.RENTAL_FEE).amount(new BigDecimal("800"))
                .status(PaymentStatus.PENDING).build();
        configure(booking, List.of(deposit, rent));

        PaymentResponse first = service.initiatePayment("customer@example.com", request(booking.getId()));
        PaymentResponse second = service.initiatePayment("customer@example.com", request(booking.getId()));

        assertEquals(first.getPaymentUrl(), second.getPaymentUrl());
        assertTrue(first.getPaymentUrl().contains("vnp_TxnRef=TXN-1"));
        assertEquals(new BigDecimal("1000"), first.getAmount());
        assertEquals(PaymentStatus.PENDING, deposit.getStatus());
        verify(payments, never()).save(any());
    }

    @Test
    void expiredUrlDoesNotCreateAnotherChargeWhileOldIpnCouldStillArrive() {
        Booking booking = booking();
        Payment deposit = deposit(booking, LocalDateTime.now(ZoneId.of("Asia/Ho_Chi_Minh"))
                .minusMinutes(16));
        Payment rent = Payment.builder().transactionId("TXN-1-R")
                .paymentType(PaymentType.RENTAL_FEE).amount(new BigDecimal("800"))
                .status(PaymentStatus.PENDING).build();
        configure(booking, List.of(deposit, rent));

        assertThrows(AppException.class,
                () -> service.initiatePayment("customer@example.com", request(booking.getId())));
        assertEquals(PaymentStatus.PENDING, deposit.getStatus());
        verify(payments, never()).save(any());
    }

    private void configure(Booking booking, List<Payment> pending) {
        User customer = User.builder().email("customer@example.com").build();
        customer.setId(booking.getCustomer().getId());
        when(users.findByEmail(customer.getEmail())).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(booking.getId(), customer.getId()))
                .thenReturn(Optional.of(booking));
        when(payments.findByBooking_IdAndStatusAndPaymentTypeIn(
                any(), any(), any())).thenReturn(pending);
        ReflectionTestUtils.setField(service, "vnpUrl", "https://sandbox.vnpayment.vn/pay");
        ReflectionTestUtils.setField(service, "vnpTmnCode", "TESTCODE");
        ReflectionTestUtils.setField(service, "vnpHashSecret", "test-secret");
        ReflectionTestUtils.setField(service, "vnpReturnUrl", "https://example.com/return");
        ReflectionTestUtils.setField(service, "vnpMerchantIp", "127.0.0.1");
    }

    private Booking booking() {
        User customer = User.builder().email("customer@example.com").build();
        customer.setId(UUID.randomUUID());
        Booking booking = Booking.builder().customer(customer)
                .status(BookingStatus.PENDING_PAYMENT)
                .expiresAt(LocalDateTime.now().plusMinutes(20))
                .storageUnit(StorageUnit.builder().unitType(UnitType.builder().build()).build())
                .build();
        booking.setId(UUID.randomUUID());
        return booking;
    }

    private Payment deposit(Booking booking, LocalDateTime created) {
        Payment payment = Payment.builder().booking(booking).transactionId("TXN-1")
                .paymentType(PaymentType.DEPOSIT).amount(new BigDecimal("200"))
                .gatewayAmount(new BigDecimal("1000"))
                .gatewayCreateDate(created.format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss")))
                .status(PaymentStatus.PENDING).build();
        payment.setId(UUID.randomUUID());
        return payment;
    }

    private PaymentInitiationRequest request(UUID bookingId) {
        PaymentInitiationRequest request = new PaymentInitiationRequest();
        request.setBookingId(bookingId);
        request.setPaymentType(PaymentType.DEPOSIT);
        return request;
    }
}
