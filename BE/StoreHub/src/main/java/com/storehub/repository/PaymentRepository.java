package com.storehub.repository;

import com.storehub.dto.response.FacilityRevenueResponse;
import com.storehub.dto.response.SystemRevenueSummaryResponse;
import com.storehub.entity.Payment;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface PaymentRepository
        extends JpaRepository<Payment, UUID> {

    Optional<Payment> findByTransactionId(String transactionId);

    @Query("select p.booking.id from Payment p where p.transactionId = :transactionId")
    Optional<UUID> findBookingIdByTransactionId(@Param("transactionId") String transactionId);

    @Query("""
            select p.id from Payment p
            where p.status in (com.storehub.enums.PaymentStatus.PENDING,
                               com.storehub.enums.PaymentStatus.FAILED)
            and p.gatewayCreateDate is not null
            and p.paymentTime < :createdBefore
            and (p.lastGatewayQueryAt is null or p.lastGatewayQueryAt < :queriedBefore)
            order by p.paymentTime asc
            """)
    List<UUID> findChargeIdsToReconcile(@Param("createdBefore") LocalDateTime createdBefore,
                                        @Param("queriedBefore") LocalDateTime queriedBefore,
                                        Pageable pageable);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Payment p where p.id = :id")
    Optional<Payment> lockById(@Param("id") UUID id);

    List<Payment> findByBooking_IdAndStatusAndPaymentTypeIn(
            UUID bookingId, PaymentStatus status, java.util.Collection<PaymentType> paymentTypes);

    @Query("""
            SELECT SUM(p.amount)
            FROM Payment p
            WHERE p.booking.storageUnit.facility.id = :facilityId
            AND p.status = com.storehub.enums.PaymentStatus.PAID
            AND p.paymentType <> com.storehub.enums.PaymentType.DEPOSIT
            """)
    java.math.BigDecimal sumPaidByFacility(@Param("facilityId") UUID facilityId);

    Optional<Payment> findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
            UUID bookingId, PaymentType paymentType, PaymentStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
           select p
           from Payment p
           where p.transactionId = :transactionId
           """)
    Optional<Payment> lockByTransactionId(
            @Param("transactionId") String transactionId
    );

    @Query("""
            SELECT new com.storehub.dto.response.FacilityRevenueResponse(
                f.id,
                f.name,
                COALESCE(SUM(CASE
                    WHEN p.paymentType <> com.storehub.enums.PaymentType.DEPOSIT
                    THEN p.amount ELSE null END), 0),
                COALESCE(
                    SUM(
                        CASE
                            WHEN p.paymentType =
                                com.storehub.enums.PaymentType.DEPOSIT
                            THEN p.amount
                            ELSE null
                        END
                    ),
                    0
                ),
                COALESCE(
                    SUM(
                        CASE
                            WHEN p.paymentType =
                                com.storehub.enums.PaymentType.RENTAL_FEE
                            THEN p.amount
                            ELSE null
                        END
                    ),
                    0
                ),
                COALESCE(
                    SUM(
                        CASE
                            WHEN p.paymentType =
                                com.storehub.enums.PaymentType.EXTRA_CHARGE
                            THEN p.amount
                            ELSE null
                        END
                    ),
                    0
                ),
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
                COALESCE(SUM(CASE
                    WHEN p.paymentType <> com.storehub.enums.PaymentType.DEPOSIT
                    THEN p.amount ELSE null END), 0),
                COALESCE(
                    SUM(
                        CASE
                            WHEN p.paymentType =
                                com.storehub.enums.PaymentType.DEPOSIT
                            THEN p.amount
                            ELSE null
                        END
                    ),
                    0
                ),
                COALESCE(
                    SUM(
                        CASE
                            WHEN p.paymentType =
                                com.storehub.enums.PaymentType.RENTAL_FEE
                            THEN p.amount
                            ELSE null
                        END
                    ),
                    0
                ),
                COALESCE(
                    SUM(
                        CASE
                            WHEN p.paymentType =
                                com.storehub.enums.PaymentType.EXTRA_CHARGE
                            THEN p.amount
                            ELSE null
                        END
                    ),
                    0
                ),
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

    Optional<Payment>
    findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
            UUID bookingId,
            PaymentType paymentType,
            PaymentStatus status,
            String note
    );

    List<Payment> findByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeAsc(
            UUID bookingId, PaymentType paymentType, PaymentStatus status, String note);

    List<Payment> findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
            UUID bookingId, PaymentType paymentType, String note,
            java.util.Collection<PaymentStatus> statuses);

    @Query("""
            SELECT COALESCE(SUM(p.amount), 0)
            FROM Payment p
            WHERE p.status = com.storehub.enums.PaymentStatus.PAID
            AND (p.note = 'OVERDUE_LATE_FEE' OR p.note = 'Phí phạt quá hạn')
            AND (:fromDate IS NULL OR p.paymentTime >= :fromDate)
            AND (:toDate IS NULL OR p.paymentTime <= :toDate)
            """)
    java.math.BigDecimal sumOverdueRevenue(
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate
    );

    @Query("""
            SELECT p FROM Payment p
            WHERE p.booking.customer.id = :customerId
            AND p.transactionId NOT LIKE '%-R'
            ORDER BY p.paymentTime DESC
            """)
    List<Payment> findCustomerPayments(@Param("customerId") UUID customerId);

    @Query("""
            SELECT p FROM Payment p
            WHERE p.booking.storageUnit.facility.id = :facilityId
            AND p.transactionId NOT LIKE '%-R'
            ORDER BY p.paymentTime DESC
            """)
    List<Payment> findFacilityPayments(@Param("facilityId") UUID facilityId);

    @Query("""
            SELECT p FROM Payment p
            WHERE p.transactionId NOT LIKE '%-R'
            ORDER BY p.paymentTime DESC
            """)
    List<Payment> findAllPayments();
}
