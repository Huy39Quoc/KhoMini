package com.storehub.scheduler;

import com.storehub.service.WaitlistService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class WaitlistExpiryScheduler {
    private final WaitlistService waitlistService;

    @Scheduled(fixedDelay = 60_000)
    public void expireOffers() {
        try {
            waitlistService.expireStaleNotifications();
        } catch (Exception e) {
            log.warn("Waitlist expiry retry on next run: {}", e.getMessage());
        }
    }
}
