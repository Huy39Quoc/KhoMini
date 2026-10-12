package com.storehub.service.impl;

import com.storehub.dto.request.RefundGatewayMetadataRequest;
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
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
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
    public List<RefundRequestResponse> list(UUID facilityId, String managerEmail) {
        requireManager(facilityId, managerEmail);
        return refunds.findTop50ByBooking_StorageUnit_Facility_IdOrderByCreatedAtDesc(facilityId)
                .stream().map(this::response).toList();
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
        return new RefundRequestResponse(refund.getId(), refund.getBooking().getId(),
                refund.getBooking().getBookingCode(), refund.getOriginalPayment().getTransactionId(),
                refund.getRequestId(), refund.getAmount(), refund.getStatus(),
                refund.getGatewayResponseCode(), refund.getGatewayTransactionStatus());
    }
}
