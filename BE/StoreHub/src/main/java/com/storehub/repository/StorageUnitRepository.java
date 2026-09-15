package com.storehub.repository;

import com.storehub.entity.StorageUnit;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface StorageUnitRepository extends JpaRepository<StorageUnit, UUID> {

    @EntityGraph(attributePaths = {"facility", "unitType"})
    Optional<StorageUnit> findWithDetailsById(UUID id);
}