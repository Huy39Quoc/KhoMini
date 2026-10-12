package com.storehub.repository;

import com.storehub.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import jakarta.persistence.LockModeType;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);
    boolean existsByEmailAndRole_NameAndFacility_IdAndIsActiveTrue(String email, String roleName, UUID facilityId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.email = :email")
    Optional<User> findByEmailForUpdate(@Param("email") String email);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.id = :id")
    Optional<User> findByIdForUpdate(@Param("id") UUID id);
    Optional<User> findByUsername(String username);
    boolean existsByEmail(String email);
    boolean existsByUsername(String username);
    boolean existsByUsernameAndIdNot(String username, UUID id);
    boolean existsByEmailAndIdNot(String email, UUID id);
    boolean existsByRole_Id(UUID roleId);

    @Query("""
            SELECT u FROM User u
            WHERE (:search IS NULL
                OR LOWER(u.username) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%'))
                OR LOWER(u.email) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%'))
                OR LOWER(u.fullName) LIKE LOWER(CONCAT('%', CAST(:search AS string), '%')))
            AND (:isActive IS NULL OR u.isActive = :isActive)
            """)
    Page<User> findAllWithFilters(
            @Param("search") String search,
            @Param("isActive") Boolean isActive,
            Pageable pageable
    );

    @Query("SELECT COUNT(u) FROM User u WHERE u.isActive = true")
    long countActiveUsers();

    List<User> findByFacility_IdAndRole_Name(
            UUID facilityId,
            String roleName
    );

    List<User> findByRole_NameAndIsActiveTrueAndFacilityIsNullOrderByFullNameAsc(
            String roleName
    );
}
