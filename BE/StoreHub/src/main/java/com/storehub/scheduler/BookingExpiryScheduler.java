package com.storehub.scheduler;

import com.storehub.entity.Booking;
import com.storehub.entity.StorageUnit;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.service.WaitlistService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.jpa.repository.Query;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Scheduler chạy mỗi 60 giây để tự động hủy các booking PENDING_PAYMENT
 * đã hết hạn (expiresAt < now()) và trả unit về AVAILABLE.
 * Sau đó trigger notify người đầu waitlist (nếu có).
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class BookingExpiryScheduler {

    private final BookingRepository bookingRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final WaitlistService waitlistService;

    @Scheduled(fixedRate = 60_000)
    @Transactional
    public void expireStaleBookings() {
        LocalDateTime now = LocalDateTime.now();

        List<Booking> expired = bookingRepository
                .findExpiredPendingBookings(BookingStatus.PENDING_PAYMENT, now);

        if (expired.isEmpty()) return;

        log.info("BookingExpiryScheduler: found {} expired booking(s) to cancel", expired.size());

        for (Booking booking : expired) {
            booking.setStatus(BookingStatus.CANCELLED);
            bookingRepository.save(booking);

            StorageUnit unit = booking.getStorageUnit();
            if (unit != null && unit.getStatus() == UnitStatus.RESERVED) {
                unit.setStatus(UnitStatus.AVAILABLE);
                storageUnitRepository.save(unit);

                try {
                    java.util.UUID facilityId = unit.getFacility() != null
                            ? unit.getFacility().getId() : null;
                    java.util.UUID unitTypeId = unit.getUnitType() != null
                            ? unit.getUnitType().getId() : null;
                    if (facilityId != null && unitTypeId != null) {
                        waitlistService.notifyNextInWaitlist(facilityId, unitTypeId);
                    }
                } catch (Exception e) {
                    log.warn("Waitlist notification failed for booking {}: {}",
                            booking.getId(), e.getMessage());
                }

                log.info("Expired booking {} cancelled, unit {} returned to AVAILABLE",
                        booking.getBookingCode(), unit.getUnitCode());
            }
        }
    }
}
