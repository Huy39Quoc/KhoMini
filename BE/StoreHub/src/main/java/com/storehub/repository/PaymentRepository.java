package com.storehub.repository;

import com.storehub.dto.response.FacilityRevenueResponse;
import com.storehub.dto.response.SystemRevenueSummaryResponse;
import com.storehub.entity.Payment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.*;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, UUID> {

    Optional<Payment> findByTransactionId(String transactionId);

    @Query("""
            SELECT new com.storehub.dto.response.FacilityRevenueResponse(
                f.id,
                f.name,
                COALESCE(SUM(p.amount), 0),
                COALESCE(SUM(CASE WHEN p.paymentType = com.storehub.enums.PaymentType.DEPOSIT THEN p.amount ELSE null END), 0),
                COALESCE(SUM(CASE WHEN p.paymentType = com.storehub.enums.PaymentType.RENTAL_FEE THEN p.amount ELSE null END), 0),
                COALESCE(SUM(CASE WHEN p.paymentType = com.storehub.enums.PaymentType.EXTRA_CHARGE THEN p.amount ELSE null END), 0),
                COUNT(p)
            )
            FROM Payment p
            JOIN p.booking b
            JOIN b.storageUnit su
            JOIN su.facility f
            WHERE p.status = com.storehub.enums.PaymentStatus.PAID
            AND (:fromDate IS NULL OR p.paymentTime >= :fromDate)
            AND (:toDate IS NULL OR p.paymentTime <= :toDate)
            GROUP BY f.id, f.name
            ORDER BY f.name
            """)
    List<FacilityRevenueResponse> sumRevenueByFacility(
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate
    );

    @Query("""
            SELECT new com.storehub.dto.response.SystemRevenueSummaryResponse(
                COALESCE(SUM(p.amount), 0),
                COALESCE(SUM(CASE WHEN p.paymentType = com.storehub.enums.PaymentType.DEPOSIT THEN p.amount ELSE null END), 0),
                COALESCE(SUM(CASE WHEN p.paymentType = com.storehub.enums.PaymentType.RENTAL_FEE THEN p.amount ELSE null END), 0),
                COALESCE(SUM(CASE WHEN p.paymentType = com.storehub.enums.PaymentType.EXTRA_CHARGE THEN p.amount ELSE null END), 0),
                COUNT(p)
            )
            FROM Payment p
            WHERE p.status = com.storehub.enums.PaymentStatus.PAID
            AND (:fromDate IS NULL OR p.paymentTime >= :fromDate)
            AND (:toDate IS NULL OR p.paymentTime <= :toDate)
            """)
    SystemRevenueSummaryResponse sumSystemRevenue(
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate
    );
}
