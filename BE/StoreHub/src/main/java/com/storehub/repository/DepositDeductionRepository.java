package com.storehub.repository;

import com.storehub.entity.DepositDeduction;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

public interface DepositDeductionRepository extends JpaRepository<DepositDeduction, UUID> {
    boolean existsByOriginalPayment_Id(UUID originalPaymentId);

    @Query(value = "select coalesce(sum(d.amount), 0) from deposit_deduction_events d "
            + "join bookings b on b.id = d.booking_id join storage_units u on u.id = b.storage_unit_id "
            + "where u.facility_id = :facilityId", nativeQuery = true)
    BigDecimal sumRetainedByFacility(@Param("facilityId") UUID facilityId);

    interface Totals {
        UUID getFacilityId();
        String getFacilityName();
        BigDecimal getOpeningBalance();
        BigDecimal getReceived();
        BigDecimal getRefunded();
        BigDecimal getRetained();
        BigDecimal getDamageRetained();
        BigDecimal getCancellationRetained();
    }

    // Cash receipt, confirmed refund and deposit conversion are separate events.
    // Refund requests that are pending/rejected never reduce the held balance.
    @Query(value = """
        WITH events AS (
            SELECT u.facility_id, p.payment_time AS event_time, p.amount AS received,
                   CAST(0 AS numeric) AS refunded, CAST(0 AS numeric) AS retained,
                   CAST(0 AS numeric) AS damage_retained, CAST(0 AS numeric) AS cancellation_retained
            FROM payments p JOIN bookings b ON b.id = p.booking_id
            JOIN storage_units u ON u.id = b.storage_unit_id
            WHERE p.payment_type = 'DEPOSIT' AND p.status IN ('PAID','REFUND_PENDING','REFUNDED')
              AND p.transaction_id NOT LIKE 'RF-%'
            UNION ALL
            SELECT u.facility_id, r.completed_at, 0, r.deposit_amount, 0, 0, 0
            FROM refund_requests r JOIN bookings b ON b.id = r.booking_id
            JOIN storage_units u ON u.id = b.storage_unit_id
            WHERE r.status = 'COMPLETED'
            UNION ALL
            SELECT u.facility_id, d.recorded_at, 0, 0, d.amount,
                   CASE WHEN d.deduction_type = 'DAMAGE' THEN d.amount ELSE 0 END,
                   CASE WHEN d.deduction_type = 'CANCELLATION' THEN d.amount ELSE 0 END
            FROM deposit_deduction_events d JOIN bookings b ON b.id = d.booking_id
            JOIN storage_units u ON u.id = b.storage_unit_id
        )
        SELECT f.id AS "facilityId", f.name AS "facilityName",
            COALESCE(SUM(CASE WHEN e.event_time < :fromDate
                THEN e.received - e.refunded - e.retained ELSE 0 END),0) AS "openingBalance",
            COALESCE(SUM(CASE WHEN e.event_time >= :fromDate THEN e.received ELSE 0 END),0) AS "received",
            COALESCE(SUM(CASE WHEN e.event_time >= :fromDate THEN e.refunded ELSE 0 END),0) AS "refunded",
            COALESCE(SUM(CASE WHEN e.event_time >= :fromDate THEN e.retained ELSE 0 END),0) AS "retained",
            COALESCE(SUM(CASE WHEN e.event_time >= :fromDate THEN e.damage_retained ELSE 0 END),0) AS "damageRetained",
            COALESCE(SUM(CASE WHEN e.event_time >= :fromDate THEN e.cancellation_retained ELSE 0 END),0) AS "cancellationRetained"
        FROM facilities f LEFT JOIN events e ON e.facility_id = f.id AND e.event_time <= :toDate
        GROUP BY f.id, f.name ORDER BY f.name
        """, nativeQuery = true)
    List<Totals> reconcile(@Param("fromDate") LocalDateTime fromDate, @Param("toDate") LocalDateTime toDate);
}
