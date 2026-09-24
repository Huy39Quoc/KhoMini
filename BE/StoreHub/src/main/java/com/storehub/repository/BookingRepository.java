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
            AND b.startDate = :date
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
            AND b.returnTime >= :startOfDay
            AND b.returnTime < :endOfDay
            ORDER BY b.returnTime ASC
            """)
    List<Booking> findCheckOutSchedule(
            @Param("facilityId") UUID facilityId,
            @Param("status") BookingStatus status,
            @Param("startOfDay") LocalDateTime startOfDay,
            @Param("endOfDay") LocalDateTime endOfDay
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
}