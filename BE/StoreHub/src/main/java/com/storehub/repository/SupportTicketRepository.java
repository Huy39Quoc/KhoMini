package com.storehub.repository;

import com.storehub.entity.SupportTicket;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface SupportTicketRepository extends JpaRepository<SupportTicket, UUID> {

    @Query("SELECT t FROM SupportTicket t WHERE t.customer.id = :customerId")
    Page<SupportTicket> findAllByCustomerId(
            @Param("customerId") UUID customerId,
            Pageable pageable
    );

    @Query("SELECT t FROM SupportTicket t WHERE t.id = :id AND t.customer.id = :customerId")
    Optional<SupportTicket> findByIdAndCustomerId(
            @Param("id") UUID id,
            @Param("customerId") UUID customerId
    );

    @Query("""
            SELECT t
            FROM SupportTicket t
            JOIN t.booking b
            JOIN b.storageUnit su
            WHERE su.facility.id = :facilityId
            """)
    Page<SupportTicket> findAllByFacilityId(
            @Param("facilityId") UUID facilityId,
            Pageable pageable
    );

    @Query("""
            SELECT t
            FROM SupportTicket t
            JOIN t.booking b
            JOIN b.storageUnit su
            WHERE t.id = :ticketId
            AND su.facility.id = :facilityId
            """)
    Optional<SupportTicket> findByIdAndFacilityId(
            @Param("ticketId") UUID ticketId,
            @Param("facilityId") UUID facilityId
    );
}