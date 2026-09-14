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
public interface SupportTicketRepository extends JpaRepository<SupportTicket, Long> {

    @Query("SELECT t FROM SupportTicket t WHERE t.customer.id = :customerId")
    Page<SupportTicket> findAllByCustomerId(@Param("customerId") UUID customerId, Pageable pageable);

    @Query("SELECT t FROM SupportTicket t WHERE t.id = :id AND t.customer.id = :customerId")
    Optional<SupportTicket> findByIdAndCustomerId(@Param("id") UUID id, @Param("customerId") UUID customerId);
}