package com.storehub.repository;

import com.storehub.entity.FacilityPolicy;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface FacilityPolicyRepository extends JpaRepository<FacilityPolicy, UUID> {

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_READ)
    @Query("select p from FacilityPolicy p where p.facility.id = :facilityId")
    Optional<FacilityPolicy> lockByFacilityId(@Param("facilityId") UUID facilityId);

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from FacilityPolicy p where p.id = :id")
    Optional<FacilityPolicy> lockById(@Param("id") UUID id);

    @Override
    @EntityGraph(attributePaths = {"facility"})
    Optional<FacilityPolicy> findById(UUID id);

    @EntityGraph(attributePaths = {"facility"})
    Optional<FacilityPolicy> findByFacility_Id(UUID facilityId);

    boolean existsByFacility_Id(UUID facilityId);

    @EntityGraph(attributePaths = {"facility"})
    @Query("""
            SELECT fp FROM FacilityPolicy fp
            WHERE (:search IS NULL
                OR LOWER(fp.facility.name) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%')))
            """)
    Page<FacilityPolicy> findAllWithFilters(@Param("search") String search, Pageable pageable);
}
