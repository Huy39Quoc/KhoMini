package com.storehub.repository;

import com.storehub.entity.StorageUnit;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface StorageUnitRepository extends JpaRepository<StorageUnit, UUID> {

    @EntityGraph(attributePaths = {"facility", "unitType"})
    Optional<StorageUnit> findWithDetailsById(UUID id);
    @Query("""
            SELECT su.facility.id, su.facility.name, su.status, COUNT(su)
            FROM StorageUnit su
            GROUP BY su.facility.id, su.facility.name, su.status
            """)
    List<Object[]> countUnitsGroupedByFacilityAndStatus();
}