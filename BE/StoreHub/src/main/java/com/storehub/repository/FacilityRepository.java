package com.storehub.repository;

import com.storehub.entity.Facility;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface FacilityRepository extends JpaRepository<Facility, UUID> {
    List<Facility> findAllByOrderByCreatedAtAsc();
}