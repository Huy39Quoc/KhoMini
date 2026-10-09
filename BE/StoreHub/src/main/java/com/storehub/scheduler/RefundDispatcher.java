package com.storehub.scheduler;

import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.enums.ActivityAction;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.RefundStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.impl.VnpayRefundClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Component
@RequiredArgsConstructor
@Slf4j
public class RefundDispatcher {
    private final RefundRequestRepository refunds;
    private final PaymentRepository payments;
    private final BookingRepository bookings;
    private final ActivityLogService activityLog;
    private final VnpayRefundClient gateway;
    private final PlatformTransactionManager transactionManager;

    @Scheduled(fixedDelay = 60_000)
    public void dispatch() {
        for (RefundRequest pending : refunds.findTop20ByStatusOrderByCreatedAtAsc(RefundStatus.QUEUED)) {
            Payload payload = inTransaction(() -> claim(pending.getId()));
            if (payload == null) continue;
            try {
                VnpayRefundClient.GatewayResult result = gateway.refund(
                        payload.requestId(), payload.txnRef(), payload.txnDate(), payload.txnNo(),
                        payload.originalAmount(), payload.amount(), payload.bookingCode());
                inTransaction(() -> { update(payload.id(), result, false); return null; });
            } catch (Exception ex) {
                log.error("Refund request {} requires reconciliation: {}", payload.requestId(), ex.toString());
                inTransaction(() -> { markNeedsReview(payload.id()); return null; });
            }
        }
        // A timeout can leave NEEDS_REVIEW, and a process restart can leave SENDING.
        // Query the gateway for these as well; never send another refund automatically.
        for (RefundRequest pending : refunds
                .findTop20ByStatusInAndUpdatedStatusAtBeforeOrderByUpdatedStatusAtAsc(
                        java.util.List.of(RefundStatus.AWAITING_CONFIRMATION,
                                RefundStatus.NEEDS_REVIEW, RefundStatus.SENDING),
                        LocalDateTime.now().minusMinutes(6))) {
            reconcile(pending.getId());
        }
    }

    public void reconcile(UUID id) {
        Payload payload = inTransaction(() -> snapshot(id));
        if (payload == null) return;
        try {
            VnpayRefundClient.GatewayResult result = gateway.query(
                    payload.txnRef(), payload.txnDate());
            inTransaction(() -> { update(payload.id(), result, true); return null; });
        } catch (Exception ex) {
            log.warn("Refund reconciliation {} failed: {}", payload.requestId(), ex.toString());
            inTransaction(() -> {
                RefundRequest request = refunds.lockById(payload.id()).orElse(null);
                if (request != null && (request.getStatus() == RefundStatus.AWAITING_CONFIRMATION
                        || request.getStatus() == RefundStatus.NEEDS_REVIEW
                        || request.getStatus() == RefundStatus.SENDING)) {
                    request.setUpdatedStatusAt(LocalDateTime.now());
                }
                return null;
            });
        }
    }

    private <T> T inTransaction(java.util.function.Supplier<T> work) {
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        transaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        return transaction.execute(status -> work.get());
    }

    private Payload claim(UUID id) {
        RefundRequest request = refunds.lockById(id).orElse(null);
        if (request == null || request.getStatus() != RefundStatus.QUEUED) return null;
        request.setStatus(RefundStatus.SENDING);
        request.setUpdatedStatusAt(LocalDateTime.now());
        return payload(request);
    }

    private Payload snapshot(UUID id) {
        RefundRequest request = refunds.findById(id).orElse(null);
        return request != null && (request.getStatus() == RefundStatus.AWAITING_CONFIRMATION
                || request.getStatus() == RefundStatus.NEEDS_REVIEW
                || request.getStatus() == RefundStatus.SENDING)
                ? payload(request) : null;
    }

    private Payload payload(RefundRequest request) {
        Payment original = request.getOriginalPayment();
        return new Payload(request.getId(), request.getRequestId(), original.getTransactionId(),
                original.getGatewayCreateDate(), original.getGatewayTransactionNo(),
                original.getGatewayAmount(), request.getAmount(), request.getBooking().getBookingCode());
    }

    private void update(UUID id, VnpayRefundClient.GatewayResult result, boolean reconciliation) {
        RefundRequest request = refunds.lockById(id).orElse(null);
        if (request == null || (reconciliation
                ? request.getStatus() != RefundStatus.AWAITING_CONFIRMATION
                    && request.getStatus() != RefundStatus.NEEDS_REVIEW
                    && request.getStatus() != RefundStatus.SENDING
                : request.getStatus() != RefundStatus.SENDING)) return;
        request.setGatewayResponseCode(result.responseCode());
        request.setGatewayTransactionStatus(result.transactionStatus());
        request.setUpdatedStatusAt(LocalDateTime.now());
        if (result.confirmed(request.getAmount())) {
            settle(request);
        } else if ("00".equals(result.responseCode()) && "09".equals(result.transactionStatus())
                && ("02".equals(result.transactionType()) || "03".equals(result.transactionType()))) {
            request.setStatus(RefundStatus.REJECTED);
        } else if ("00".equals(result.responseCode())
                && ("02".equals(result.transactionType()) || "03".equals(result.transactionType()))) {
            request.setStatus(RefundStatus.AWAITING_CONFIRMATION);
        } else if ("94".equals(result.responseCode())) {
            request.setStatus(RefundStatus.NEEDS_REVIEW);
        } else if (!reconciliation && java.util.Set.of("02", "03", "91", "95", "97")
                .contains(result.responseCode())) {
            request.setStatus(RefundStatus.REJECTED);
        } else if (!reconciliation) {
            request.setStatus(RefundStatus.NEEDS_REVIEW);
        }
    }

    private void markNeedsReview(UUID id) {
        RefundRequest request = refunds.lockById(id).orElse(null);
        if (request != null && request.getStatus() == RefundStatus.SENDING) {
            request.setStatus(RefundStatus.NEEDS_REVIEW);
            request.setUpdatedStatusAt(LocalDateTime.now());
        }
    }

    private void settle(RefundRequest request) {
        Booking booking = bookings.lockById(request.getBooking().getId()).orElseThrow();
        Payment original = request.getOriginalPayment();
        BigDecimal depositRemaining = booking.getDepositPaid().subtract(request.getDepositAmount());
        if (depositRemaining.signum() < 0) throw new IllegalStateException("Refund exceeds deposit");
        booking.setDepositPaid(depositRemaining);
        // The booking may contain deposits from several captured attempts.
        // Settle this original transaction independently of the booking total.
        BigDecimal originalRemaining = original.getAmount().subtract(request.getDepositAmount());
        if (originalRemaining.signum() < 0) throw new IllegalStateException("Refund exceeds original deposit");
        if (originalRemaining.signum() == 0) {
            original.setStatus(PaymentStatus.REFUNDED);
        } else {
            original.setAmount(originalRemaining);
        }
        if (request.getRentalAmount().signum() > 0) {
            Payment rent = payments.findByTransactionId(original.getTransactionId() + "-R")
                    .orElseThrow();
            BigDecimal remaining = rent.getAmount().subtract(request.getRentalAmount());
            if (remaining.signum() < 0) throw new IllegalStateException("Refund exceeds rent");
            if (remaining.signum() == 0) rent.setStatus(PaymentStatus.REFUNDED);
            else rent.setAmount(remaining);
        }
        request.getRefundPayment().setStatus(PaymentStatus.REFUNDED);
        request.setStatus(RefundStatus.COMPLETED);
        activityLog.recordSystem(ActivityAction.REFUND_PROCESSED, "BOOKING", booking.getId(),
                "VNPay refund confirmed: " + request.getAmount() + " request " + request.getRequestId());
    }

    private record Payload(UUID id, String requestId, String txnRef, String txnDate,
                           String txnNo, BigDecimal originalAmount, BigDecimal amount,
                           String bookingCode) {}
}
