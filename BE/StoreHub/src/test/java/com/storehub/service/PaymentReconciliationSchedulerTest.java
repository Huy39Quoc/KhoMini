package com.storehub.service;

import com.storehub.entity.Payment;
import com.storehub.enums.PaymentStatus;
import com.storehub.repository.PaymentRepository;
import com.storehub.scheduler.PaymentReconciliationScheduler;
import com.storehub.service.impl.PaymentServiceImpl;
import com.storehub.service.impl.VnpayRefundClient;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PaymentReconciliationSchedulerTest {
    @Mock PaymentRepository payments;
    @Mock VnpayRefundClient gateway;
    @Mock PaymentServiceImpl paymentService;
    @Mock PlatformTransactionManager manager;

    @Test
    void missingIpnIsRecoveredOnlyWhenSignedGatewayQueryConfirmsOriginalCharge() throws Exception {
        UUID id = UUID.randomUUID();
        Payment payment = Payment.builder().transactionId("TXN-1")
                .gatewayCreateDate("20261009230000")
                .gatewayAmount(new BigDecimal("1000"))
                .status(PaymentStatus.PENDING).build();
        when(payments.findChargeIdsToReconcile(any(), any(), any())).thenReturn(List.of(id));
        when(payments.lockById(id)).thenReturn(Optional.of(payment));
        when(manager.getTransaction(any())).thenAnswer(call -> new SimpleTransactionStatus());
        VnpayRefundClient.GatewayResult confirmed =
                new VnpayRefundClient.GatewayResult("00", "00", "01", "100000", "123456");
        when(gateway.query("TXN-1", "20261009230000")).thenReturn(confirmed);

        new PaymentReconciliationScheduler(payments, gateway, paymentService, manager).reconcile();

        assertNotNull(payment.getLastGatewayQueryAt());
        verify(paymentService).reconcileConfirmedCharge("TXN-1", confirmed);
    }

    @Test
    void ambiguousGatewayResponseNeverConfirmsCharge() throws Exception {
        UUID id = UUID.randomUUID();
        Payment payment = Payment.builder().transactionId("TXN-1")
                .gatewayCreateDate("20261009230000")
                .gatewayAmount(new BigDecimal("1000"))
                .status(PaymentStatus.PENDING).build();
        when(payments.findChargeIdsToReconcile(any(), any(), any())).thenReturn(List.of(id));
        when(payments.lockById(id)).thenReturn(Optional.of(payment));
        when(manager.getTransaction(any())).thenAnswer(call -> new SimpleTransactionStatus());
        when(gateway.query("TXN-1", "20261009230000"))
                .thenReturn(new VnpayRefundClient.GatewayResult("00", "01", "01", "100000"));

        new PaymentReconciliationScheduler(payments, gateway, paymentService, manager).reconcile();

        verify(paymentService, never()).reconcileConfirmedCharge(any(), any());
    }
}
