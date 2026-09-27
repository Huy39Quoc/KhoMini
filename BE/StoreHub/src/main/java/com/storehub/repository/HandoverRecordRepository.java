package com.storehub.repository;

import com.storehub.entity.HandoverRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface HandoverRecordRepository extends JpaRepository<HandoverRecord, UUID> {

    List<HandoverRecord> findByBookingIdOrderByRecordedAtDesc(UUID bookingId);
}