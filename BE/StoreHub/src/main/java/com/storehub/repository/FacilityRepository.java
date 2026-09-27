package com.storehub.repository;

import com.storehub.entity.Facility;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface FacilityRepository extends JpaRepository<Facility, UUID> {
    List<Facility> findAllByOrderByCreatedAtAsc();
    boolean existsByCode(String code);

    boolean existsByCodeAndIdNot(String code, UUID id);

    @Query("""
            SELECT f FROM Facility f
            WHERE (:search IS NULL
                OR LOWER(f.name) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%'))
                OR LOWER(f.code) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%'))
                OR LOWER(f.city) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%')))
            AND (:status IS NULL OR f.status = :status)
            """)
    Page<Facility> findAllWithFilters(
            @Param("search") String search,
            @Param("status") com.storehub.enums.FacilityStatus status,
            Pageable pageable
    );
}