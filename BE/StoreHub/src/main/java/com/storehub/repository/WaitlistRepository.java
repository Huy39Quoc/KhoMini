package com.storehub.repository;

import com.storehub.entity.Waitlist;
import com.storehub.enums.WaitlistStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.time.Instant;

@Repository
public interface WaitlistRepository extends JpaRepository<Waitlist, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            SELECT w FROM Waitlist w
            JOIN FETCH w.customer
            WHERE w.facility.id = :facilityId
            AND w.unitType.id = :unitTypeId
            AND w.status = :status
            ORDER BY w.createdAt ASC
            """)
    List<Waitlist> findByFacilityAndUnitTypeAndStatus(
            @Param("facilityId") UUID facilityId,
            @Param("unitTypeId") UUID unitTypeId,
            @Param("status") WaitlistStatus status
    );

    boolean existsByCustomer_IdAndFacility_IdAndUnitType_IdAndStatus(
            UUID customerId,
            UUID facilityId,
            UUID unitTypeId,
            WaitlistStatus status
    );

    Optional<Waitlist> findByCustomer_IdAndFacility_IdAndUnitType_IdAndStatus(
            UUID customerId,
            UUID facilityId,
            UUID unitTypeId,
            WaitlistStatus status
    );

    boolean existsByCustomer_IdAndFacility_IdAndUnitType_IdAndStatusIn(
            UUID customerId, UUID facilityId, UUID unitTypeId, List<WaitlistStatus> statuses);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            SELECT w FROM Waitlist w JOIN FETCH w.customer
            WHERE w.facility.id = :facilityId AND w.unitType.id = :unitTypeId
              AND w.status IN :statuses ORDER BY w.createdAt ASC
            """)
    List<Waitlist> findOpenForUpdate(@Param("facilityId") UUID facilityId,
                                     @Param("unitTypeId") UUID unitTypeId,
                                     @Param("statuses") List<WaitlistStatus> statuses);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT w FROM Waitlist w WHERE w.status = :status AND w.offerExpiresAt <= :now")
    List<Waitlist> findExpiredOffersForUpdate(@Param("status") WaitlistStatus status,
                                              @Param("now") Instant now);

    @Query("SELECT DISTINCT w.facility.id, w.unitType.id FROM Waitlist w WHERE w.status = :status")
    List<Object[]> findWaitingPairs(@Param("status") WaitlistStatus status);

    @org.springframework.data.jpa.repository.Modifying
    @Query("""
            UPDATE Waitlist w SET w.status = :fulfilled
            WHERE w.customer.id = :customerId AND w.facility.id = :facilityId
              AND w.unitType.id = :unitTypeId AND w.status IN :openStatuses
            """)
    int markFulfilled(@Param("customerId") UUID customerId,
                      @Param("facilityId") UUID facilityId,
                      @Param("unitTypeId") UUID unitTypeId,
                      @Param("openStatuses") List<WaitlistStatus> openStatuses,
                      @Param("fulfilled") WaitlistStatus fulfilled);

    List<Waitlist> findByCustomer_IdOrderByCreatedAtDesc(UUID customerId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT w FROM Waitlist w WHERE w.id = :id AND w.customer.id = :customerId")
    Optional<Waitlist> findOwnedForUpdate(@Param("id") UUID id,
                                          @Param("customerId") UUID customerId);
}
