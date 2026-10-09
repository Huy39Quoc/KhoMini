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
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

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
    private final PlatformTransactionManager transactionManager;

    @Scheduled(fixedRate = 60_000)
    public void expireStaleBookings() {
        LocalDateTime now = LocalDateTime.now();

        List<Booking> expired = bookingRepository
                .findExpiredPendingBookings(BookingStatus.PENDING_PAYMENT, now);

        if (expired.isEmpty()) return;

        log.info("BookingExpiryScheduler: found {} expired booking(s) to cancel", expired.size());

        for (Booking candidate : expired) {
            ReleasedUnit released = new TransactionTemplate(transactionManager).execute(status -> {
                // Re-read under lock: callback and cancellation use the same booking lock.
                Booking booking = bookingRepository.lockById(candidate.getId()).orElse(null);
                if (booking == null || booking.getStatus() != BookingStatus.PENDING_PAYMENT
                        || booking.getExpiresAt() == null
                        || !booking.getExpiresAt().isBefore(LocalDateTime.now())) {
                    return null;
                }
                booking.setStatus(BookingStatus.CANCELLED);
                bookingRepository.save(booking);

                StorageUnit unit = booking.getStorageUnit();
                if (unit != null && unit.getStatus() == UnitStatus.RESERVED) {
                    unit.setStatus(UnitStatus.AVAILABLE);
                    storageUnitRepository.save(unit);
                    return new ReleasedUnit(booking.getId(), booking.getBookingCode(), unit.getUnitCode(),
                            unit.getFacility() != null ? unit.getFacility().getId() : null,
                            unit.getUnitType() != null ? unit.getUnitType().getId() : null);
                }
                return null;
            });
            if (released != null) {
                log.info("Expired booking {} cancelled, unit {} returned to AVAILABLE",
                        released.bookingCode(), released.unitCode());
                if (released.facilityId() != null && released.unitTypeId() != null) {
                    try {
                        waitlistService.notifyNextInWaitlist(released.facilityId(), released.unitTypeId());
                    } catch (Exception e) {
                        log.warn("Waitlist notification failed for booking {}: {}",
                                released.bookingId(), e.getMessage());
                    }
                }
            }
        }
    }

    private record ReleasedUnit(UUID bookingId, String bookingCode, String unitCode,
                                UUID facilityId, UUID unitTypeId) {}
}
