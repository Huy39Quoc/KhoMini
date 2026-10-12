package com.storehub.scheduler;

import com.storehub.entity.Payment;
import com.storehub.enums.PaymentStatus;
import com.storehub.repository.PaymentRepository;
import com.storehub.service.impl.PaymentServiceImpl;
import com.storehub.service.impl.VnpayRefundClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDateTime;
import java.util.UUID;
import java.util.function.Supplier;

/** Queries VNPay for charges whose IPN/return was lost. No network I/O holds a DB lock. */
@Component
@RequiredArgsConstructor
@Slf4j
public class PaymentReconciliationScheduler {
    private final PaymentRepository payments;
    private final VnpayRefundClient gateway;
    private final PaymentServiceImpl paymentService;
    private final PlatformTransactionManager transactionManager;

    @Scheduled(fixedDelay = 60_000)
    public void reconcile() {
        LocalDateTime now = LocalDateTime.now();
        for (UUID id : payments.findChargeIdsToReconcile(now.minusMinutes(2),
                now.minusMinutes(5), PageRequest.of(0, 50))) {
            Charge charge = inTransaction(() -> claim(id));
            if (charge == null) continue;
            try {
                VnpayRefundClient.GatewayResult result = gateway.query(
                        charge.transactionId(), charge.gatewayCreateDate());
                if (result.confirmedCharge(charge.amount())) {
                    inTransaction(() -> {
                        paymentService.reconcileConfirmedCharge(charge.transactionId(), result);
                        return null;
                    });
                } else {
                    // 91 (not found), 94 (rate limited), a pending gateway status,
                    // and other inconclusive results must not mark the charge failed.
                    log.info("Charge {} still awaiting gateway reconciliation (response {}, status {})",
                            charge.transactionId(), result.responseCode(), result.transactionStatus());
                }
            } catch (Exception ex) {
                log.warn("Charge {} reconciliation deferred: {}", charge.transactionId(), ex.toString());
            }
        }
    }

    private Charge claim(UUID id) {
        Payment payment = payments.lockById(id).orElse(null);
        if (payment == null || (payment.getStatus() != PaymentStatus.PENDING
                && payment.getStatus() != PaymentStatus.FAILED)
                || payment.getGatewayCreateDate() == null
                || payment.getGatewayAmount() == null
                || (payment.getLastGatewayQueryAt() != null
                && !payment.getLastGatewayQueryAt().isBefore(LocalDateTime.now().minusMinutes(5)))) {
            return null;
        }
        payment.setLastGatewayQueryAt(LocalDateTime.now());
        return new Charge(payment.getTransactionId(), payment.getGatewayCreateDate(),
                payment.getGatewayAmount());
    }

    private <T> T inTransaction(Supplier<T> work) {
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        transaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        return transaction.execute(status -> work.get());
    }

    private record Charge(String transactionId, String gatewayCreateDate,
                          java.math.BigDecimal amount) {}
}
