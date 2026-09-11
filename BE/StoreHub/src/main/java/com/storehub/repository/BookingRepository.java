package com.storehub.repository;

import com.storehub.entity.Booking;
import com.storehub.enums.BookingStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BookingRepository extends JpaRepository<Booking, Long> {

    @Query("SELECT b FROM Booking b WHERE b.customer.id = :customerId AND b.status IN (:statuses)")
    List<Booking> findActiveBookingsByCustomerId(
            @Param("customerId") UUID customerId,
            @Param("statuses") List<BookingStatus> statuses
    );

    @Query("SELECT b FROM Booking b WHERE b.id = :id AND b.customer.id = :customerId")
    Optional<Booking> findByIdAndCustomerId(
            @Param("id") Long id,
            @Param("customerId") UUID customerId
    );
}