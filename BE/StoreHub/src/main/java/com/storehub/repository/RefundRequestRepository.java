package com.storehub.repository;

import com.storehub.entity.RefundRequest;
import com.storehub.enums.RefundStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.time.LocalDateTime;

public interface RefundRequestRepository extends JpaRepository<RefundRequest, UUID> {
    boolean existsByBooking_Id(UUID bookingId);
    boolean existsByIdAndBooking_StorageUnit_Facility_Id(UUID id, UUID facilityId);
    Optional<RefundRequest> findByRefundPayment_Id(UUID refundPaymentId);
    List<RefundRequest> findTop50ByBooking_StorageUnit_Facility_IdOrderByCreatedAtDesc(UUID facilityId);

    List<RefundRequest> findTop20ByStatusOrderByCreatedAtAsc(RefundStatus status);

    List<RefundRequest> findTop20ByStatusInAndUpdatedStatusAtBeforeOrderByUpdatedStatusAtAsc(
            List<RefundStatus> statuses, LocalDateTime before);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from RefundRequest r where r.id = :id")
    Optional<RefundRequest> lockById(@Param("id") UUID id);
}
