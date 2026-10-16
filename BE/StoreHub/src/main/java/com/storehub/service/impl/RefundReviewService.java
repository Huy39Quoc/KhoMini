package com.storehub.service.impl;

import com.storehub.dto.request.RefundGatewayMetadataRequest;
import com.storehub.common.PageResponse;
import com.storehub.dto.response.RefundRequestResponse;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.enums.RefundStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.scheduler.RefundDispatcher;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class RefundReviewService {
    private final RefundRequestRepository refunds;
    private final UserRepository users;
    private final RefundDispatcher dispatcher;

    public void reconcile(UUID facilityId, UUID refundId, String managerEmail) {
        requireManager(facilityId, managerEmail);
        // The transaction is closed before the outbound gateway call.
        verifyRefundFacility(facilityId, refundId);
        dispatcher.reconcile(refundId);
    }

    public void verifyRefundFacility(UUID facilityId, UUID id) {
        if (!refunds.existsByIdAndBooking_StorageUnit_Facility_Id(id, facilityId)) {
            throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
        }
    }

    @Transactional(readOnly = true)
    public PageResponse<RefundRequestResponse> list(UUID facilityId, String managerEmail,
                                                     int page, int size) {
        requireManager(facilityId, managerEmail);
        if (page < 0 || size < 1 || size > 100) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        return PageResponse.from(refunds.findForManager(facilityId, RefundStatus.COMPLETED,
                LocalDateTime.now(), PageRequest.of(page, size)).map(this::response));
    }

    @Transactional
    public RefundRequestResponse provideMetadata(UUID facilityId, UUID refundId,
                                                  String managerEmail, RefundGatewayMetadataRequest details) {
        requireManager(facilityId, managerEmail);
        RefundRequest refund = requireRefund(facilityId, refundId);
        if (refund.getStatus() != RefundStatus.MISSING_METADATA
                && refund.getStatus() != RefundStatus.REJECTED) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        if (details.getOriginalAmount().compareTo(refund.getAmount()) < 0) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        if (refund.getStatus() == RefundStatus.REJECTED) rotateRequestId(refund);
        Payment original = refund.getOriginalPayment();
        original.setGatewayCreateDate(details.getTransactionDate());
        original.setGatewayTransactionNo(details.getTransactionNo());
        original.setGatewayAmount(details.getOriginalAmount());
        refund.setStatus(RefundStatus.QUEUED);
        refund.setUpdatedStatusAt(LocalDateTime.now());
        return response(refund);
    }

    @Transactional
    public RefundRequestResponse retryRejected(UUID facilityId, UUID refundId, String managerEmail) {
        requireManager(facilityId, managerEmail);
        RefundRequest refund = requireRefund(facilityId, refundId);
        if (refund.getStatus() != RefundStatus.REJECTED) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        rotateRequestId(refund);
        refund.setStatus(RefundStatus.QUEUED);
        refund.setUpdatedStatusAt(LocalDateTime.now());
        return response(refund);
    }

    @Transactional
    public RefundRequestResponse confirmBankTransfer(UUID facilityId, UUID refundId,
                                                     String managerEmail, com.storehub.dto.request.ConfirmBankTransferRequest request) {
        requireManager(facilityId, managerEmail);
        RefundRequest refund = requireRefund(facilityId, refundId);
        // QUEUED/NEEDS_REVIEW thuộc luồng hoàn qua VNPay; xác nhận chuyển khoản tay ở đây
        // có thể làm hoàn tiền hai lần.
        if (refund.getStatus() != RefundStatus.AWAITING_BANK_TRANSFER) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        LocalDateTime now = LocalDateTime.now();
        refund.setStatus(RefundStatus.COMPLETED);
        refund.setCompletedAt(now);
        refund.setUpdatedStatusAt(now);
        refund.setTransferReference(request.getTransferReference());

        com.storehub.entity.Booking booking = refund.getBooking();
        if (booking != null && booking.getDepositPaid() != null) {
            java.math.BigDecimal depositRemaining = booking.getDepositPaid().subtract(refund.getDepositAmount());
            if (depositRemaining.signum() >= 0) {
                booking.setDepositPaid(depositRemaining);
            }
        }

        Payment original = refund.getOriginalPayment();
        if (original != null) {
            java.math.BigDecimal remaining = original.getAmount().subtract(refund.getDepositAmount());
            if (remaining.signum() <= 0) {
                original.setStatus(com.storehub.enums.PaymentStatus.REFUNDED);
            }
        }

        Payment refundPayment = refund.getRefundPayment();
        if (refundPayment != null) {
            refundPayment.setStatus(com.storehub.enums.PaymentStatus.REFUNDED);
            refundPayment.setPaymentTime(now);
            if (request.getNotes() != null && !request.getNotes().isBlank()) {
                String existingNote = refundPayment.getNote() != null ? refundPayment.getNote() : "";
                refundPayment.setNote(existingNote + " | Ref: " + request.getTransferReference() + " (" + request.getNotes() + ")");
            }
        }

        return response(refund);
    }

    private void rotateRequestId(RefundRequest refund) {
        String requestId = UUID.randomUUID().toString().replace("-", "").toUpperCase();
        refund.setRequestId(requestId);
        refund.getRefundPayment().setTransactionId("RF-" + requestId);
        refund.setGatewayResponseCode(null);
        refund.setGatewayTransactionStatus(null);
    }

    private RefundRequest requireRefund(UUID facilityId, UUID id) {
        RefundRequest refund = refunds.lockById(id)
                .orElseThrow(() -> new AppException(ErrorCode.PAYMENT_NOT_FOUND));
        if (!facilityId.equals(refund.getBooking().getStorageUnit().getFacility().getId())) {
            throw new AppException(ErrorCode.PAYMENT_NOT_FOUND);
        }
        return refund;
    }

    private void requireManager(UUID facilityId, String email) {
        if (!users.existsByEmailAndRole_NameAndFacility_IdAndIsActiveTrue(
                email, "FACILITY_MANAGER", facilityId)) {
            throw new AppException(ErrorCode.FORBIDDEN);
        }
    }

    private RefundRequestResponse response(RefundRequest refund) {
        boolean unresolved = refund.getStatus() != RefundStatus.COMPLETED;
        return new RefundRequestResponse(
                refund.getId(),
                refund.getBooking().getId(),
                refund.getBooking().getBookingCode(),
                refund.getOriginalPayment() != null ? refund.getOriginalPayment().getTransactionId() : null,
                refund.getRequestId(),
                refund.getAmount(),
                refund.getStatus(),
                refund.getGatewayResponseCode(),
                refund.getGatewayTransactionStatus(),
                refund.getDueAt(),
                unresolved && refund.getDueAt() != null && refund.getDueAt().isBefore(LocalDateTime.now()),
                refund.getDamageDeduction() != null ? refund.getDamageDeduction() : java.math.BigDecimal.ZERO,
                refund.getBankCode(),
                refund.getBankAccountNumber(),
                refund.getBankAccountName(),
                refund.getTransferReference()
        );
    }
}
