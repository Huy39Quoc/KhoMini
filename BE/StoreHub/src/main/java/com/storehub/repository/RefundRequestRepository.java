package com.storehub.repository;

import com.storehub.entity.RefundRequest;
import com.storehub.dto.response.FacilityRevenueResponse;
import com.storehub.dto.response.SystemRevenueSummaryResponse;
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
import java.math.BigDecimal;

public interface RefundRequestRepository extends JpaRepository<RefundRequest, UUID> {
    boolean existsByBooking_Id(UUID bookingId);
    boolean existsByOriginalPayment_Id(UUID paymentId);
    boolean existsByIdAndBooking_StorageUnit_Facility_Id(UUID id, UUID facilityId);
    Optional<RefundRequest> findByRefundPayment_Id(UUID refundPaymentId);
    Optional<RefundRequest> findByOriginalPayment_Id(UUID originalPaymentId);
    List<RefundRequest> findTop50ByBooking_StorageUnit_Facility_IdOrderByCreatedAtDesc(UUID facilityId);

    List<RefundRequest> findTop20ByStatusOrderByDueAtAsc(RefundStatus status);

    List<RefundRequest> findTop20ByStatusInAndUpdatedStatusAtBeforeOrderByUpdatedStatusAtAsc(
            List<RefundStatus> statuses, LocalDateTime before);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from RefundRequest r where r.id = :id")
    Optional<RefundRequest> lockById(@Param("id") UUID id);

    @Query("""
            SELECT new com.storehub.dto.response.FacilityRevenueResponse(
                f.id, f.name,
                COALESCE(SUM(r.rentalAmount), 0),
                COALESCE(SUM(r.depositAmount), 0),
                COALESCE(SUM(CASE WHEN charge.paymentType = com.storehub.enums.PaymentType.DEPOSIT
                    THEN r.rentalAmount ELSE null END), 0),
                COALESCE(SUM(CASE WHEN charge.paymentType = com.storehub.enums.PaymentType.EXTRA_CHARGE
                    THEN r.rentalAmount ELSE null END), 0),
                0L)
            FROM RefundRequest r
            JOIN r.booking b JOIN b.storageUnit su JOIN su.facility f
            JOIN r.originalPayment charge
            WHERE r.status = com.storehub.enums.RefundStatus.COMPLETED
            AND r.completedAt >= :fromDate
            AND r.completedAt <= :toDate
            GROUP BY f.id, f.name
            """)
    List<FacilityRevenueResponse> sumCompletedRefundsByFacility(
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate);

    @Query("""
            SELECT new com.storehub.dto.response.SystemRevenueSummaryResponse(
                COALESCE(SUM(r.rentalAmount), 0),
                COALESCE(SUM(r.depositAmount), 0),
                COALESCE(SUM(CASE WHEN charge.paymentType = com.storehub.enums.PaymentType.DEPOSIT
                    THEN r.rentalAmount ELSE null END), 0),
                COALESCE(SUM(CASE WHEN charge.paymentType = com.storehub.enums.PaymentType.EXTRA_CHARGE
                    THEN r.rentalAmount ELSE null END), 0),
                0L)
            FROM RefundRequest r
            JOIN r.originalPayment charge
            WHERE r.status = com.storehub.enums.RefundStatus.COMPLETED
            AND r.completedAt >= :fromDate
            AND r.completedAt <= :toDate
            """)
    SystemRevenueSummaryResponse sumCompletedRefundsSystem(
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate);

    @Query("""
            SELECT COALESCE(SUM(r.rentalAmount), 0)
            FROM RefundRequest r
            JOIN r.originalPayment charge
            WHERE r.status = com.storehub.enums.RefundStatus.COMPLETED
            AND (charge.note = 'OVERDUE_LATE_FEE'
                 OR charge.note = 'Phí phạt quá hạn')
            AND r.completedAt >= :fromDate
            AND r.completedAt <= :toDate
            """)
    BigDecimal sumCompletedOverdueRefunds(@Param("fromDate") LocalDateTime fromDate,
                                          @Param("toDate") LocalDateTime toDate);

    @Query("""
            SELECT COALESCE(SUM(r.rentalAmount), 0)
            FROM RefundRequest r
            WHERE r.status = com.storehub.enums.RefundStatus.COMPLETED
            AND r.booking.storageUnit.facility.id = :facilityId
            """)
    BigDecimal sumCompletedRentalRefundsByFacility(@Param("facilityId") UUID facilityId);
}
