package com.storehub.repository;

import com.storehub.entity.UnitType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface UnitTypeRepository extends JpaRepository<UnitType, UUID> {

    /**
     * Lấy danh sách UnitType kèm số lượng kho AVAILABLE tại facility (nếu có).
     * Dùng Enum literal trong JPQL thay vì magic string 'AVAILABLE'.
     */
    @Query("""
        SELECT ut,
               COUNT(su.id)
        FROM UnitType ut
        LEFT JOIN StorageUnit su ON su.unitType = ut
             AND su.status = com.storehub.enums.UnitStatus.AVAILABLE
             AND (:facilityId IS NULL OR su.facility.id = :facilityId)
        GROUP BY ut.id, ut.typeName, ut.dimensions, ut.areaSqm, ut.basePricePerMonth, ut.depositAmount
        ORDER BY ut.basePricePerMonth ASC
    """)
    List<Object[]> findCatalogUnitTypesWithAvailableCount(@Param("facilityId") UUID facilityId);
}