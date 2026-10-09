package com.storehub.service;

import com.storehub.entity.Payment;
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

import static org.junit.jupiter.api.Assertions.assertEquals;
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
