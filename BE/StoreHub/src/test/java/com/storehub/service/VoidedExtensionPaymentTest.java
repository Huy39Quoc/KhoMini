package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.enums.BookingStatus;
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
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static com.storehub.common.PaymentNotes.RENTAL_EXTENSION;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VoidedExtensionPaymentTest {
    @Mock PaymentRepository payments;
    @Mock BookingRepository bookings;
    @Mock RefundRequestRepository refunds;
    @Mock UserRepository users;
    @Mock EmailService email;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock WaitlistService waitlist;
    @InjectMocks PaymentServiceImpl service;

    @Test
    void lateIpnForCancelledExtensionRefundsInsteadOfApplyingNewRequest() {
        Booking booking = Booking.builder().bookingCode("BK-1")
                .status(BookingStatus.ACTIVE).depositPaid(new BigDecimal("200"))
                .endDate(LocalDate.of(2026, 12, 1)).rentalMonths(2)
                .totalRentalFee(new BigDecimal("800"))
                .pendingExtraMonths(3).pendingExtensionFee(new BigDecimal("1000"))
                .build();
        booking.setId(UUID.randomUUID());
        Payment cancelled = Payment.builder().booking(booking)
                .transactionId("TXN-OLD").paymentType(PaymentType.EXTRA_CHARGE)
                .note(RENTAL_EXTENSION).status(PaymentStatus.FAILED)
                .amount(new BigDecimal("1000"))
                .gatewayAmount(new BigDecimal("1000"))
                .gatewayCreateDate("20261009230000")
                .voidedAt(LocalDateTime.now()).build();
        cancelled.setId(UUID.randomUUID());
        when(payments.findBookingIdByTransactionId("TXN-OLD")).thenReturn(Optional.of(booking.getId()));
        when(bookings.lockById(booking.getId())).thenReturn(Optional.of(booking));
        when(payments.lockByTransactionId("TXN-OLD")).thenReturn(Optional.of(cancelled));
        when(payments.save(any(Payment.class))).thenAnswer(call -> call.getArgument(0));
        ReflectionTestUtils.setField(service, "vnpHashSecret", "test-secret");

        assertEquals(PaymentStatus.REFUND_PENDING, service.processVnpayCallback(signedSuccess()).getStatus());
        assertEquals(LocalDate.of(2026, 12, 1), booking.getEndDate());
        assertEquals(3, booking.getPendingExtraMonths());
        assertEquals(new BigDecimal("200"), booking.getDepositPaid());
        ArgumentCaptor<RefundRequest> request = ArgumentCaptor.forClass(RefundRequest.class);
        verify(refunds).save(request.capture());
        assertEquals(new BigDecimal("1000"), request.getValue().getAmount());
        assertEquals(BigDecimal.ZERO, request.getValue().getDepositAmount());
        assertEquals(new BigDecimal("1000"), request.getValue().getRentalAmount());
        assertEquals(cancelled, request.getValue().getOriginalPayment());
    }

    private Map<String, String> signedSuccess() {
        Map<String, String> params = new HashMap<>();
        params.put("vnp_Amount", "100000");
        params.put("vnp_ResponseCode", "00");
        params.put("vnp_TransactionStatus", "00");
        params.put("vnp_TxnRef", "TXN-OLD");
        params.put("vnp_SecureHash", VNPayUtil.hmacSHA512("test-secret",
                "vnp_Amount=100000&vnp_ResponseCode=00&vnp_TransactionStatus=00&vnp_TxnRef=TXN-OLD"));
        return params;
    }
}
