package com.storehub.repository;

import com.storehub.entity.Booking;
import com.storehub.enums.BookingStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BookingRepository extends JpaRepository<Booking, UUID> {

    @Query("""
            SELECT b FROM Booking b
            JOIN FETCH b.storageUnit su
            LEFT JOIN FETCH su.facility
            LEFT JOIN FETCH su.unitType
            WHERE b.customer.id = :customerId
            AND b.status IN (:statuses)
            ORDER BY b.startDate DESC
            """)
    List<Booking> findActiveBookingsByCustomerId(
            @Param("customerId") UUID customerId,
            @Param("statuses") List<BookingStatus> statuses
    );

    @Query("""
            SELECT b FROM Booking b
            JOIN FETCH b.storageUnit su
            JOIN FETCH su.facility f
            JOIN FETCH su.unitType
            JOIN FETCH b.customer
            WHERE f.id = :facilityId
            AND b.status IN (:statuses)
            ORDER BY b.endDate ASC
            """)
    List<Booking> findFacilityContracts(
            @Param("facilityId") UUID facilityId,
            @Param("statuses") List<BookingStatus> statuses
    );

    @Query("""
            SELECT b.storageUnit.facility.id, COUNT(b)
            FROM Booking b
            WHERE b.status = com.storehub.enums.BookingStatus.ACTIVE
            AND b.overdueDetectedAt IS NOT NULL
            GROUP BY b.storageUnit.facility.id
            """)
    List<Object[]> countOverdueGroupedByFacility();

    @Query("SELECT b.status, COUNT(b) FROM Booking b GROUP BY b.status")
    List<Object[]> countGroupedByStatus();

    @Query("""
            SELECT b FROM Booking b
            JOIN FETCH b.storageUnit su
            JOIN FETCH su.facility
            JOIN FETCH su.unitType
            WHERE b.id = :id
            AND b.customer.id = :customerId
            """)
    Optional<Booking> findByIdAndCustomerId(
            @Param("id") UUID id,
            @Param("customerId") UUID customerId
    );

    @Query("""
            SELECT b FROM Booking b
            JOIN FETCH b.storageUnit su
            JOIN FETCH su.facility f
            LEFT JOIN FETCH su.unitType
            WHERE f.id = :facilityId
            AND b.status = :status
            AND b.startDate <= :date
            ORDER BY b.startDate ASC
            """)
    List<Booking> findCheckInSchedule(
            @Param("facilityId") UUID facilityId,
            @Param("status") BookingStatus status,
            @Param("date") LocalDate date
    );

    @Query("""
            SELECT b FROM Booking b
            JOIN FETCH b.storageUnit su
            JOIN FETCH su.facility f
            LEFT JOIN FETCH su.unitType
            WHERE f.id = :facilityId
            AND b.status = :status
            AND (
                (b.returnTime IS NOT NULL AND b.returnTime < :endOfDay)
                OR (b.returnTime IS NULL AND b.endDate <= :date)
            )
            ORDER BY b.endDate ASC
            """)
    List<Booking> findCheckOutSchedule(
            @Param("facilityId") UUID facilityId,
            @Param("status") BookingStatus status,
            @Param("endOfDay") LocalDateTime endOfDay,
            @Param("date") LocalDate date
    );

    @Query("""
            SELECT b FROM Booking b
            JOIN FETCH b.storageUnit su
            JOIN FETCH su.facility f
            LEFT JOIN FETCH su.unitType
            WHERE b.id = :bookingId
            AND f.id = :facilityId
            """)
    Optional<Booking> findByIdAndFacilityId(
            @Param("bookingId") UUID bookingId,
            @Param("facilityId") UUID facilityId
    );

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select b from Booking b where b.id = :id")
    Optional<Booking> lockById(@Param("id") UUID id);

    boolean existsByStorageUnit_IdAndStatusIn(
            UUID unitId,
            List<BookingStatus> statuses
    );

    @Query("""
            SELECT b FROM Booking b
            JOIN FETCH b.storageUnit su
            LEFT JOIN FETCH su.facility
            LEFT JOIN FETCH su.unitType
            WHERE b.status = :status
            AND b.expiresAt IS NOT NULL
            AND b.expiresAt < :now
            """)
    List<Booking> findExpiredPendingBookings(
            @Param("status") BookingStatus status,
            @Param("now") LocalDateTime now
    );

    long countByStorageUnit_Facility_IdAndStatusAndOverdueDetectedAtIsNotNull(
            UUID facilityId,
            BookingStatus status
    );

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
        SELECT b FROM Booking b
        JOIN FETCH b.storageUnit su
        JOIN FETCH su.facility f
        WHERE b.status = :status
        AND b.endDate < :today
        ORDER BY b.endDate ASC
        """)
    List<Booking> findActiveOverdueBookingsForUpdate(
            @Param("status") BookingStatus status,
            @Param("today") LocalDate today
    );

    @Query("""
        SELECT b
        FROM Booking b
        JOIN FETCH b.customer
        JOIN FETCH b.storageUnit su
        JOIN FETCH su.facility f
        JOIN FETCH su.unitType
        WHERE f.id = :facilityId
        AND b.status = :status
        ORDER BY b.startDate ASC, b.createdAt ASC
        """)
    List<Booking> findByFacilityIdAndStatus(
            @Param("facilityId") UUID facilityId,
            @Param("status") BookingStatus status
    );
}
