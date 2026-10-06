package com.storehub.scheduler;

import com.storehub.dto.response.OverdueConfigResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.enums.ActivityAction;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.exception.AppException;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.service.ActivityLogService;
import com.storehub.service.FacilityPolicyService;
import com.storehub.service.PricingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Component
@RequiredArgsConstructor
@Slf4j
public class OverdueScheduler {



    private static final ZoneId BUSINESS_ZONE =
            ZoneId.of("Asia/Ho_Chi_Minh");

    private final BookingRepository bookingRepository;
    private final PaymentRepository paymentRepository;
    private final FacilityPolicyRepository facilityPolicyRepository;
    private final FacilityPolicyService facilityPolicyService;
    private final PricingService pricingService;
    private final ActivityLogService activityLogService;

    @Scheduled(
            cron = "${app.overdue.scheduler-cron:0 5 0 * * *}",
            zone = "Asia/Ho_Chi_Minh"
    )
    @Transactional
    public void processOverdueBookings() {
        LocalDate today = LocalDate.now(BUSINESS_ZONE);
        LocalDateTime now = LocalDateTime.now(BUSINESS_ZONE);

        List<Booking> bookings = bookingRepository
                .findActiveOverdueBookingsForUpdate(
                        BookingStatus.ACTIVE,
                        today
                );

        if (bookings.isEmpty()) {
            return;
        }

        log.info(
                "OverdueScheduler: found {} active booking(s) past end date",
                bookings.size()
        );

        for (Booking booking : bookings) {
            try {
                processOneBooking(booking, today, now);
            } catch (AppException exception) {
                log.warn(
                        "OverdueScheduler skipped booking {}: {}",
                        booking.getBookingCode(),
                        exception.getMessage()
                );
            }
        }
    }

    private void processOneBooking(
            Booking booking,
            LocalDate today,
            LocalDateTime now
    ) {
        UUID facilityId = booking
                .getStorageUnit()
                .getFacility()
                .getId();

        // Cơ sở chưa có chính sách: bỏ qua TRƯỚC khi gọi service. Nếu để service
        // ném AppException trong transaction chung, cả batch bị đánh dấu
        // rollback-only và mọi booking quá hạn khác cũng không được xử lý.
        if (!facilityPolicyRepository.existsByFacility_Id(facilityId)) {
            log.warn("OverdueScheduler skipped booking {}: facility {} has no policy",
                    booking.getBookingCode(), facilityId);
            return;
        }

        OverdueConfigResponse config =
                facilityPolicyService.getOverdueConfig(facilityId);

        long overdueDays = ChronoUnit.DAYS.between(
                booking.getEndDate(),
                today
        );

        long chargeableDays = Math.max(
                0,
                overdueDays - config.graceDays()
        );

        if (chargeableDays <= 0) {
            return;
        }

        if (booking.getOverdueDetectedAt() == null) {
            booking.setOverdueDetectedAt(now);

            activityLogService.recordSystem(
                    ActivityAction.OVERDUE_DETECTED,
                    "BOOKING",
                    booking.getId(),
                    "Booking " + booking.getBookingCode()
                            + " became overdue after "
                            + config.graceDays()
                            + " grace day(s)"
            );
        }

        updateLateFee(
                booking,
                facilityId,
                chargeableDays,
                now
        );

        if (overdueDays >= config.accessDisableDays()
                && booking.getAccessDisabledAt() == null) {

            booking.setAccessCode(null);
            booking.setAccessPin(null);
            booking.setUnitLocked(true);
            booking.setAccessDisabledAt(now);

            activityLogService.recordSystem(
                    ActivityAction.OVERDUE_ACCESS_DISABLED,
                    "BOOKING",
                    booking.getId(),
                    "Disabled access credentials for overdue booking "
                            + booking.getBookingCode()
            );
        }

        if (overdueDays >= config.sealingDays()
                && booking.getSealingPendingAt() == null) {

            booking.setSealingPendingAt(now);

            activityLogService.recordSystem(
                    ActivityAction.OVERDUE_SEALING_PENDING,
                    "BOOKING",
                    booking.getId(),
                    "Booking " + booking.getBookingCode()
                            + " was marked pending for sealing"
            );
        }

        bookingRepository.save(booking);
    }

    private void updateLateFee(
            Booking booking,
            UUID facilityId,
            long chargeableDays,
            LocalDateTime now
    ) {
        BigDecimal calculatedTotal = pricingService
                .calculateLateFee(
                        facilityId,
                        chargeableDays
                );

        BigDecimal previousTotal =
                booking.getOverdueFeeAccrued() != null
                        ? booking.getOverdueFeeAccrued()
                        : BigDecimal.ZERO;

        BigDecimal increment =
                calculatedTotal.subtract(previousTotal);

        if (increment.signum() <= 0) {
            return;
        }

        Payment pendingPayment = paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                        booking.getId(),
                        PaymentType.EXTRA_CHARGE,
                        PaymentStatus.PENDING,
                        OVERDUE_LATE_FEE
                )
                .orElseGet(() -> Payment.builder()
                        .transactionId(createTransactionId())
                        .booking(booking)
                        .amount(BigDecimal.ZERO)
                        .paymentType(PaymentType.EXTRA_CHARGE)
                        .status(PaymentStatus.PENDING)
                        .paymentMethod(null)
                        .note(OVERDUE_LATE_FEE)
                        .paymentTime(now)
                        .build());

        pendingPayment.setAmount(
                pendingPayment.getAmount().add(increment)
        );

        paymentRepository.save(pendingPayment);
        booking.setOverdueFeeAccrued(calculatedTotal);
    }

    private String createTransactionId() {
        return "OD-" + UUID.randomUUID()
                .toString()
                .replace("-", "")
                .substring(0, 20)
                .toUpperCase();
    }
}