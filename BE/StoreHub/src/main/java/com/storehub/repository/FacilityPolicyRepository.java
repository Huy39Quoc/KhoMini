package com.storehub.repository;

import com.storehub.entity.FacilityPolicy;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface FacilityPolicyRepository extends JpaRepository<FacilityPolicy, UUID> {
    Optional<FacilityPolicy> findByFacility_Id(UUID facilityId);
}