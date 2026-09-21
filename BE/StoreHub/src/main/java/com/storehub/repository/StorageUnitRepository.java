package com.storehub.repository;

import com.storehub.entity.StorageUnit;
import com.storehub.enums.UnitStatus;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StorageUnitRepository extends JpaRepository<StorageUnit, UUID> {

    @EntityGraph(attributePaths = {"facility", "unitType"})
    Optional<StorageUnit> findWithDetailsById(UUID id);

    // Derived query type-safe bằng Enum UnitStatus – không hardcode magic string
    List<StorageUnit> findByFacility_IdAndUnitType_IdAndStatus(
            UUID facilityId,
            UUID unitTypeId,
            UnitStatus status
    );

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @org.springframework.data.jpa.repository.Query(
            "select u from StorageUnit u where u.id = :id"
    )
    Optional<StorageUnit> lockById(
            @org.springframework.data.repository.query.Param("id") UUID id
    );

    @EntityGraph(attributePaths = {"unitType"})
    List<StorageUnit> findByFacility_IdOrderByUnitCodeAsc(
            UUID facilityId
    );

    boolean existsByFacility_IdAndUnitCode(
            UUID facilityId,
            String unitCode
    );

    @org.springframework.data.jpa.repository.Query(
            value = """
                SELECT id FROM storage_units
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
            @org.springframework.data.repository.query.Param("facilityId")
            UUID facilityId,

            @org.springframework.data.repository.query.Param("unitTypeId")
            UUID unitTypeId
    );
}