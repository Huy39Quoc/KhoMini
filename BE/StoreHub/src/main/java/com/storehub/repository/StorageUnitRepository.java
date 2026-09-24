package com.storehub.repository;

import com.storehub.entity.StorageUnit;
import com.storehub.enums.UnitStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StorageUnitRepository
        extends JpaRepository<StorageUnit, UUID> {

    @EntityGraph(attributePaths = {"facility", "unitType"})
    Optional<StorageUnit> findWithDetailsById(UUID id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from StorageUnit u where u.id = :id")
    Optional<StorageUnit> lockById(
            @Param("id") UUID id
    );

    @EntityGraph(attributePaths = {"unitType"})
    List<StorageUnit> findByFacility_IdOrderByUnitCodeAsc(
            UUID facilityId
    );

    boolean existsByFacility_IdAndUnitCode(
            UUID facilityId,
            String unitCode
    );

    @Query(
            value = """
                SELECT id
                FROM storage_units
                WHERE facility_id = :facilityId
                  AND unit_type_id = :unitTypeId
                  AND status = 'AVAILABLE'
                ORDER BY unit_code
                LIMIT 1
                FOR UPDATE SKIP LOCKED
                """,
            nativeQuery = true
    )
    Optional<UUID> claimAvailableUnitId(
            @Param("facilityId") UUID facilityId,
            @Param("unitTypeId") UUID unitTypeId
    );

    List<StorageUnit> findByFacility_IdAndUnitType_IdAndStatus(
            UUID facilityId,
            UUID unitTypeId,
            UnitStatus status
    );

    @Query("""
            SELECT su.facility.id,
                   su.facility.name,
                   su.status,
                   COUNT(su)
            FROM StorageUnit su
            GROUP BY su.facility.id,
                     su.facility.name,
                     su.status
            """)
    List<Object[]> countUnitsGroupedByFacilityAndStatus();
}