package com.storehub.repository;

import com.storehub.entity.Waitlist;
import com.storehub.enums.WaitlistStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface WaitlistRepository extends JpaRepository<Waitlist, UUID> {

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
}
