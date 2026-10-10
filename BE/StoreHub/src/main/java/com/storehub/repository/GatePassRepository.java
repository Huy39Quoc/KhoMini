package com.storehub.repository;

import com.storehub.entity.GatePass;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface GatePassRepository extends JpaRepository<GatePass, UUID> {
    @Query("select p.booking.id from GatePass p where p.tokenHash = :hash")
    Optional<UUID> findBookingIdByTokenHash(@Param("hash") String hash);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from GatePass p join fetch p.booking where p.tokenHash = :hash")
    Optional<GatePass> lockByTokenHash(@Param("hash") String hash);

    @Modifying
    @Query("update GatePass p set p.revokedAt = :now where p.booking.id = :bookingId and p.usedAt is null and p.revokedAt is null")
    int revokeUnusedForBooking(@Param("bookingId") UUID bookingId, @Param("now") Instant now);
}
