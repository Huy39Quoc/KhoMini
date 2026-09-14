package com.storehub.repository;

import com.storehub.entity.RolePermission;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RolePermissionRepository extends JpaRepository<RolePermission, UUID> {

    boolean existsByRole_IdAndPermission_Id(UUID roleId, UUID permissionId);

    Optional<RolePermission> findByRole_IdAndPermission_Id(UUID roleId, UUID permissionId);

    List<RolePermission> findAllByRole_Id(UUID roleId);

    List<RolePermission> findAllByPermission_Id(UUID permissionId);

    @Query("""
            SELECT rp FROM RolePermission rp
            WHERE (:roleId IS NULL OR rp.role.id = :roleId)
            AND (:permissionId IS NULL OR rp.permission.id = :permissionId)
            AND (:search IS NULL
                OR LOWER(rp.role.name) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%'))
                OR LOWER(rp.permission.name) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%'))
                OR LOWER(rp.description) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%')))
            AND (:isActive IS NULL OR rp.isActive = :isActive)
            """)
    Page<RolePermission> findAllWithFilters(
            @Param("roleId") UUID roleId,
            @Param("permissionId") UUID permissionId,
            @Param("search") String search,
            @Param("isActive") Boolean isActive,
            Pageable pageable
    );
}
