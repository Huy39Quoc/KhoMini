package com.storehub.service.impl;

import com.storehub.entity.Waitlist;
import com.storehub.enums.UnitStatus;
import com.storehub.enums.WaitlistStatus;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.WaitlistRepository;
import com.storehub.service.EmailService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class WaitlistNotificationDispatcher {
    private final WaitlistRepository waitlistRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final EmailService emailService;

    @Async
    @Transactional
    public void dispatch(UUID facilityId, UUID unitTypeId) {
        if (!storageUnitRepository.existsByFacility_IdAndUnitType_IdAndStatus(
                facilityId, unitTypeId, UnitStatus.AVAILABLE)) return;

        // Lock open entries so simultaneous release events cannot notify two customers.
        List<Waitlist> open = waitlistRepository.findOpenForUpdate(
                facilityId, unitTypeId, List.of(WaitlistStatus.WAITING, WaitlistStatus.NOTIFIED));
        Instant now = Instant.now();
        for (Waitlist entry : open) {
            if (entry.getStatus() == WaitlistStatus.NOTIFIED) {
                if (entry.getOfferExpiresAt() == null || entry.getOfferExpiresAt().isAfter(now)) return;
                entry.setStatus(WaitlistStatus.EXPIRED);
                waitlistRepository.save(entry);
            }
        }

        Waitlist first = open.stream()
                .filter(entry -> entry.getStatus() == WaitlistStatus.WAITING)
                .findFirst().orElse(null);
        if (first == null) return;

        try {
            // This email method must be synchronous: only a confirmed send starts
            // the 24-hour offer. On failure WAITING remains eligible for retry.
            emailService.sendWaitlistNotificationEmail(
                    first.getCustomer().getEmail(), first.getCustomer().getFullName(),
                    first.getFacility().getName(), first.getUnitType().getTypeName());
        } catch (Exception exception) {
            log.error("Waitlist email failed for entry {}; scheduler will retry", first.getId(), exception);
            return;
        }

        Instant deliveredAt = Instant.now();
        first.setStatus(WaitlistStatus.NOTIFIED);
        first.setNotifiedAt(deliveredAt);
        first.setOfferExpiresAt(deliveredAt.plus(24, ChronoUnit.HOURS));
        waitlistRepository.save(first);
    }
}
