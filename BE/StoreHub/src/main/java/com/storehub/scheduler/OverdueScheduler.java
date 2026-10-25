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
import com.storehub.common.OverduePolicySnapshot;
import com.storehub.repository.PaymentRepository;
import com.storehub.service.ActivityLogService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;
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

    /**
     * Bring the late-fee ledger up to the current date while the caller holds the
     * booking lock. Both checkout and extension must account for missed nightly
     * runs; callers that reject a transition commit the newly accrued debt.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean accrueOutstandingForCheckout(Booking booking, LocalDateTime now) {
        long overdueDays = ChronoUnit.DAYS.between(booking.getEndDate(), now.toLocalDate());
        if (overdueDays > 0) {
            OverdueConfigResponse config = OverduePolicySnapshot.read(booking);
            long chargeableDays = Math.max(0, overdueDays - config.graceDays());
            if (chargeableDays > 0) {
                if (booking.getOverdueDetectedAt() == null) {
                    booking.setOverdueDetectedAt(now);
                    activityLogService.recordSystem(ActivityAction.OVERDUE_DETECTED,
                            "BOOKING", booking.getId(),
                            "Booking " + booking.getBookingCode() + " became overdue after "
                                    + config.graceDays() + " grace day(s)");
                }
                updateLateFee(booking, chargeableDays, now);
                bookingRepository.save(booking);
            }
        }
        return paymentRepository.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                        booking.getId(), PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                        List.of(PaymentStatus.PENDING, PaymentStatus.FAILED))
                .stream().anyMatch(p -> p.getVoidedAt() == null
                        && p.getAmount() != null && p.getAmount().signum() > 0);
    }

    private void processOneBooking(
            Booking booking,
            LocalDate today,
            LocalDateTime now
    ) {
        OverdueConfigResponse config = OverduePolicySnapshot.read(booking);

        long overdueDays = ChronoUnit.DAYS.between(
                booking.getEndDate(),
                today
        );

        long chargeableDays = Math.max(
                0,
                overdueDays - config.graceDays()
        );

        if (overdueDays <= 0) {
            return;
        }
        boolean accessDue = overdueDays >= config.accessDisableDays();
        boolean sealingDue = overdueDays >= config.sealingDays();
        if (chargeableDays <= 0 && !accessDue && !sealingDue) {
            return;
        }

        if (booking.getOverdueDetectedAt() == null) {
            booking.setOverdueDetectedAt(now);

            activityLogService.recordSystem(
                    ActivityAction.OVERDUE_DETECTED,
                    "BOOKING",
                    booking.getId(),
                    "Booking " + booking.getBookingCode()
                            + " requires overdue handling; late-fee grace period: "
                            + config.graceDays()
                            + " day(s)"
            );
        }

        // Grace applies only to late fees. Security deadlines must still be evaluated.
        if (chargeableDays > 0) {
            updateLateFee(booking, chargeableDays, now);
        }

        if (accessDue
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

        if (sealingDue
                && booking.getSealingPendingAt() == null) {

            LocalDateTime previousApproval = booking.getSealingApprovedAt();
            booking.setSealingPendingAt(now);
            booking.setSealingApprovedAt(null);

            activityLogService.recordSystem(
                    ActivityAction.OVERDUE_SEALING_PENDING,
                    "BOOKING",
                    booking.getId(),
                    "Booking " + booking.getBookingCode()
                            + " was marked pending for sealing"
                            + (previousApproval != null
                                ? "; prior episode approval expired: " + previousApproval : "")
            );
        }

        bookingRepository.save(booking);
    }

    private void updateLateFee(
            Booking booking,
            long chargeableDays,
            LocalDateTime now
    ) {
        BigDecimal calculatedTotal = OverduePolicySnapshot.read(booking).dailyLateFee()
                .multiply(BigDecimal.valueOf(chargeableDays))
                .setScale(2, java.math.RoundingMode.HALF_UP);

        // Migrate unpaid FAILED attempts from older releases before adding today's fee.
        // Never change a URL already sent to VNPay: any late capture of the old
        // reference must go through the existing voided-at refund path.
        paymentRepository.findByBooking_IdAndPaymentTypeAndNoteAndStatusIn(
                        booking.getId(), PaymentType.EXTRA_CHARGE, OVERDUE_LATE_FEE,
                        List.of(PaymentStatus.FAILED))
                .stream().filter(p -> p.getVoidedAt() == null && p.getAmount() != null
                        && p.getAmount().signum() > 0)
                .forEach(failed -> {
                    failed.setVoidedAt(now);
                    paymentRepository.save(failed);
                    paymentRepository.save(Payment.builder()
                            .transactionId(createTransactionId())
                            .booking(booking)
                            .amount(failed.getAmount())
                            .paymentType(PaymentType.EXTRA_CHARGE)
                            .status(PaymentStatus.PENDING)
                            .paymentMethod(failed.getPaymentMethod())
                            .note(OVERDUE_LATE_FEE)
                            .paymentTime(failed.getPaymentTime())
                            .build());
                });

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
                .filter(payment -> payment.getGatewayCreateDate() == null)
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
