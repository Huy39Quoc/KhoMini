package com.storehub.repository;

import com.storehub.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    boolean existsByUsernameAndIdNot(String username, UUID id);
    boolean existsByEmailAndIdNot(String email, UUID id);
    boolean existsByUsername(String username);
    boolean existsByEmail(String email);
    @Query("""
              Select u from User u
              where (: search is null or lower(u.fullName) like lower(concat('%',:search,'%') )
               or lower(u.email) like lower(concat('%',:search,'%') )
               or lower(u.username) like lower(concat('%',:search,'%') ))
               and (:isActive is null or u.isActive = :isActive) \s
            """)
    Page<User> findAllWithFilters(
            @Param("search") String search,
            @Param("isActive") boolean isActive,
            Pageable pageable);
    Optional<User> findByUsername(String username);
    Optional<User> findByEmail(String email);
}
