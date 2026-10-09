package com.storehub.entity;

import com.storehub.enums.BookingStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "bookings")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Booking extends BaseEntity {

    @Column(name = "booking_code", nullable = false, unique = true, length = 30)
    private String bookingCode;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "customer_id", nullable = false)
    private User customer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "storage_unit_id", nullable = false)
    private StorageUnit storageUnit;

    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;

    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;

    @Column(name = "rental_months", nullable = false)
    private Integer rentalMonths;

    @Column(name = "total_rental_fee", nullable = false, precision = 12, scale = 2)
    private BigDecimal totalRentalFee;

    @Column(name = "deposit_paid", nullable = false, precision = 12, scale = 2)
    private BigDecimal depositPaid;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 30)
    private BookingStatus status;

    @Column(name = "access_code", length = 20)
    private String accessCode;

    // Mã PIN mở khóa, lưu dạng băm BCrypt (không bao giờ lưu/trả về PIN dạng chữ rõ).
    @Column(name = "access_pin", length = 100)
    private String accessPin;

    @Column(name = "pin_failed_attempts", nullable = false)
    @Builder.Default
    private Integer pinFailedAttempts = 0;

    @Column(name = "pin_locked_until")
    private LocalDateTime pinLockedUntil;

    @Column(name = "pin_updated_at")
    private LocalDateTime pinUpdatedAt;

    @Column(name = "handed_over_by_staff_id")
    private UUID handedOverByStaffId;

    @Column(name = "handover_time")
    private LocalDateTime handoverTime;

    @Column(name = "return_time")
    private LocalDateTime returnTime;

    @Column(name = "scheduled_return_time")
    private LocalDateTime scheduledReturnTime;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_check_in_staff_id")
    private User assignedCheckInStaff;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_check_out_staff_id")
    private User assignedCheckOutStaff;

    @Column(name = "expires_at")
    private LocalDateTime expiresAt;

    @Column(name = "pending_extra_months")
    private Integer pendingExtraMonths;

    @Column(name = "pending_extension_fee", precision = 12, scale = 2)
    private BigDecimal pendingExtensionFee;

    @Column(name = "unit_locked", nullable = false)
    @Builder.Default
    private Boolean unitLocked = true;

    @Column(name = "overdue_detected_at")
    private LocalDateTime overdueDetectedAt;

    @Column(
            name = "overdue_fee_accrued",
            nullable = false,
            precision = 12,
            scale = 2
    )
    @Builder.Default
    private BigDecimal overdueFeeAccrued = BigDecimal.ZERO;

    @Column(name = "access_disabled_at")
    private LocalDateTime accessDisabledAt;

    @Column(name = "sealing_pending_at")
    private LocalDateTime sealingPendingAt;

    // Facility Manager đã duyệt niêm phong cho hợp đồng quá hạn
    @Column(name = "sealing_approved_at")
    private LocalDateTime sealingApprovedAt;
}
