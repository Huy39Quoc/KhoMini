package com.storehub.service.impl;

import com.storehub.dto.request.HandoverRequest;
import com.storehub.dto.request.UpdateUnitStatusRequest;
import com.storehub.dto.response.DailyScheduleResponse;
import com.storehub.dto.response.HandoverRecordResponse;
import com.storehub.dto.response.HandoverResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.HandoverRecord;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.exception.OutstandingOverdueFeeException;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.HandoverRecordRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UserRepository;
import com.storehub.entity.FacilityAccess;
import com.storehub.service.FacilityOperationsService;
import com.storehub.service.PaymentService;
import com.storehub.service.WaitlistService;
import com.storehub.scheduler.OverdueScheduler;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class FacilityOperationsServiceImpl
        implements FacilityOperationsService {

    private final BookingRepository bookingRepository;
    private final HandoverRecordRepository handoverRecordRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final UserRepository userRepository;
    private final FacilityAccess facilityAccess;
    private final PaymentService paymentService;
    private final WaitlistService waitlistService;
    private final OverdueScheduler overdueScheduler;
    private final org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;
    private final com.storehub.service.ActivityLogService activityLogService;
    private final com.storehub.service.CloudinaryService cloudinaryService;
    private final com.storehub.service.NotificationService notificationService;

    @Override
    @Transactional
    public DailyScheduleResponse assignAppointment(UUID bookingId, UUID facilityId,
                                                   String managerEmail, String scheduleType, UUID staffId) {
        User manager = facilityAccess.require(managerEmail, facilityId);
        if (manager.getRole() == null || !"FACILITY_MANAGER".equals(manager.getRole().getName())) {
            throw new AppException(ErrorCode.FORBIDDEN);
        }
        Booking booking = bookingRepository.lockById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));
        if (booking.getStorageUnit() == null || booking.getStorageUnit().getFacility() == null
                || !facilityId.equals(booking.getStorageUnit().getFacility().getId())) {
            throw new AppException(ErrorCode.BOOKING_NOT_FOUND);
        }
        if (!("CHECK_IN".equals(scheduleType) && booking.getStatus() == BookingStatus.CONFIRMED)
                && !("CHECK_OUT".equals(scheduleType) && booking.getStatus() == BookingStatus.ACTIVE)) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        User staff = null;
        if (staffId != null) {
            staff = userRepository.findByIdForUpdate(staffId)
                    .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
            if (!Boolean.TRUE.equals(staff.getIsActive()) || staff.getRole() == null
                    || !"STAFF".equals(staff.getRole().getName()) || staff.getFacility() == null
                    || !facilityId.equals(staff.getFacility().getId())) {
                throw new AppException(ErrorCode.INVALID_REQUEST);
            }
            LocalDateTime appointmentTime = "CHECK_IN".equals(scheduleType)
                    ? checkInTime(booking)
                    : booking.getScheduledReturnTime() != null
                        ? booking.getScheduledReturnTime() : booking.getEndDate().atTime(9, 0);
            // Appointments are selected to minute precision. Keep the staff row
            // locked through conflict detection and save, including concurrent requests.
            LocalDateTime slotStart = appointmentTime.truncatedTo(java.time.temporal.ChronoUnit.MINUTES);
            if (bookingRepository.existsConflictingStaffAppointment(
                    staffId, bookingId, slotStart, slotStart.plusMinutes(1))) {
                throw new AppException(ErrorCode.STAFF_APPOINTMENT_CONFLICT);
            }
        }
        User previousStaff = "CHECK_IN".equals(scheduleType)
                ? booking.getAssignedCheckInStaff()
                : booking.getAssignedCheckOutStaff();

        if ("CHECK_IN".equals(scheduleType)) {
            booking.setAssignedCheckInStaff(staff);
        } else {
            booking.setAssignedCheckOutStaff(staff);
        }
        bookingRepository.save(booking);
        LocalDateTime scheduled = "CHECK_IN".equals(scheduleType)
                ? checkInTime(booking)
                : booking.getScheduledReturnTime() != null
                    ? booking.getScheduledReturnTime() : booking.getEndDate().atTime(9, 0);

        String typeLabel = "CHECK_IN".equals(scheduleType) ? "bàn giao nhận kho" : "nghiệm thu trả kho";
        String unitCode = (booking.getStorageUnit() != null && booking.getStorageUnit().getUnitCode() != null)
                ? booking.getStorageUnit().getUnitCode() : "";
        String timeStr = scheduled.format(java.time.format.DateTimeFormatter.ofPattern("HH:mm dd/MM/yyyy"));
        com.storehub.entity.Facility aptFacility = booking.getStorageUnit() != null ? booking.getStorageUnit().getFacility() : null;

        if (previousStaff != null && (staff == null || !previousStaff.getId().equals(staff.getId()))) {
            if (notificationService != null) {
                notificationService.notifyUser(
                        previousStaff,
                        "Hủy phân công lịch hẹn",
                        "Lịch " + typeLabel + " cho đơn " + booking.getBookingCode()
                                + (unitCode.isEmpty() ? "" : " (Ngăn " + unitCode + ")")
                                + " lúc " + timeStr + " đã được phân công lại.",
                        com.storehub.enums.NotificationType.APPOINTMENT_SCHEDULED,
                        booking.getId(),
                        "BOOKING",
                        aptFacility
                );
            }
        }

        if (staff != null) {
            if (notificationService != null) {
                notificationService.notifyUser(
                        staff,
                        "Phân công lịch hẹn mới",
                        "Bạn được phân công " + typeLabel + " cho đơn " + booking.getBookingCode()
                                + (unitCode.isEmpty() ? "" : " (Ngăn " + unitCode + ")")
                                + " vào lúc " + timeStr + ".",
                        com.storehub.enums.NotificationType.APPOINTMENT_SCHEDULED,
                        booking.getId(),
                        "BOOKING",
                        aptFacility
                );
            }
        }

        return toScheduleResponse(booking, scheduleType, scheduled);
    }

    @Override
    @Transactional(readOnly = true)
    public List<DailyScheduleResponse> getDailySchedule(
            UUID facilityId,
            LocalDate date,
            String staffEmail
    ) {
        if (facilityId == null || date == null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        User viewer = facilityAccess.require(staffEmail, facilityId);

        List<DailyScheduleResponse> result = new ArrayList<>();

        // Việc đã trễ hẹn (chưa nhận/trả) vẫn hiện cho tới khi xử lý xong, nhưng chỉ khi xem
        // hôm nay hoặc ngày đã qua. Khi xem ngày tương lai chỉ hiện việc đúng ngày đó,
        // tránh cùng một đơn xuất hiện lặp lại ở nhiều ngày.
        boolean viewingFutureDay = date.isAfter(LocalDate.now());

        List<Booking> checkInBookings =
                bookingRepository.findCheckInSchedule(
                        facilityId,
                        BookingStatus.CONFIRMED,
                        date
                );

        for (Booking booking : checkInBookings) {
            if (!visibleToStaff(viewer, booking.getAssignedCheckInStaff())) continue;
            if (viewingFutureDay && booking.getStartDate().isBefore(date)) continue;
            result.add(toScheduleResponse(
                    booking,
                    "CHECK_IN",
                    checkInTime(booking)
            ));
        }

        LocalDateTime endOfDay = date.plusDays(1).atStartOfDay();

        List<Booking> checkOutBookings =
                bookingRepository.findCheckOutSchedule(
                        facilityId,
                        BookingStatus.ACTIVE,
                        endOfDay,
                        date
                );

        for (Booking booking : checkOutBookings) {
            if (!visibleToStaff(viewer, booking.getAssignedCheckOutStaff())) continue;
            // Khách đã hẹn trả kho: theo giờ hẹn. Khách chưa hẹn nhưng hợp đồng
            // đã đến/quá hạn: theo ngày hết hạn.
            LocalDateTime scheduled = booking.getScheduledReturnTime() != null
                    ? booking.getScheduledReturnTime()
                    : booking.getEndDate().atTime(9, 0);
            if (viewingFutureDay && scheduled.toLocalDate().isBefore(date)) continue;

            result.add(toScheduleResponse(
                    booking,
                    "CHECK_OUT",
                    scheduled
            ));
        }

        result.sort(
                Comparator.comparing(
                        DailyScheduleResponse::getScheduledTime,
                        Comparator.nullsLast(
                                Comparator.naturalOrder()
                        )
                )
        );

        return result;
    }

    @Override
    @Transactional(readOnly = true)
    public List<HandoverRecordResponse> getHandoverHistory(
            UUID bookingId,
            UUID facilityId,
            String staffEmail
    ) {
        facilityAccess.require(staffEmail, facilityId);

        bookingRepository.findByIdAndFacilityId(bookingId, facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        return handoverRecordRepository
                .findByBookingIdOrderByRecordedAtDesc(bookingId)
                .stream()
                .map(record -> new HandoverRecordResponse(
                        record.getId(),
                        bookingId,
                        record.getRecordType(),
                        record.getUnitCondition(),
                        record.getNotes(),
                        record.getStaff().getId(),
                        record.getStaff().getFullName(),
                        record.getRecordedAt(),
                        record.getDamageFee(),
                        record.getDamageReason(),
                        record.getPhotos()
                ))
                .toList();
    }

    @Override
    @Transactional
    public com.storehub.dto.response.SmartAccessResponse resetCustomerPin(
            UUID bookingId,
            UUID facilityId,
            String staffEmail
    ) {
        User staff = facilityAccess.require(staffEmail, facilityId);

        Booking booking = bookingRepository
                .lockById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        if (booking.getStorageUnit() == null
                || booking.getStorageUnit().getFacility() == null
                || !facilityId.equals(booking.getStorageUnit().getFacility().getId())) {
            throw new AppException(ErrorCode.BOOKING_NOT_FOUND);
        }
        if (booking.getStatus() != BookingStatus.ACTIVE) {
            throw new AppException(ErrorCode.BOOKING_NOT_CHECKED_IN);
        }
        // Hợp đồng quá hạn đã bị thu hồi truy cập thì phải thanh toán/gia hạn trước
        if (booking.getAccessDisabledAt() != null) {
            throw new AppException(ErrorCode.ACCESS_DISABLED_OVERDUE);
        }

        String newPin = String.valueOf(100000 + new java.security.SecureRandom().nextInt(900000));
        booking.setAccessPin(passwordEncoder.encode(newPin));
        booking.setPinUpdatedAt(LocalDateTime.now());
        booking.setPinFailedAttempts(0);
        booking.setPinLockedUntil(null);
        booking.setUnitLocked(true);
        bookingRepository.save(booking);

        activityLogService.record(
                staff.getId(),
                com.storehub.enums.ActivityAction.ACCESS_CREDENTIAL_UPDATE,
                "BOOKING",
                booking.getId(),
                "Staff reset access PIN for booking " + booking.getBookingCode(),
                null,
                null
        );

        return com.storehub.dto.response.SmartAccessResponse.builder()
                .bookingId(booking.getId())
                .unitCode(booking.getStorageUnit().getUnitCode())
                .pinSet(true)
                .pinUpdatedAt(booking.getPinUpdatedAt())
                .locked(true)
                .attemptsRemaining(5)
                .generatedPin(newPin)
                .build();
    }

    @Override
    @Transactional
    public HandoverResponse checkIn(
            UUID bookingId,
            UUID facilityId,
            String staffEmail,
            HandoverRequest request
    ) {
        validateHandoverConditions(request);
        User staff = facilityAccess.require(
                staffEmail,
                facilityId
        );

        Booking booking = bookingRepository
                .lockById(bookingId)
                .orElseThrow(() -> new AppException(
                        ErrorCode.BOOKING_NOT_FOUND
                ));

        if (booking.getStorageUnit() == null) {
            throw new AppException(
                    ErrorCode.STORAGE_UNIT_NOT_FOUND
            );
        }

        if (booking.getStorageUnit().getFacility() == null
                || !facilityId.equals(
                booking.getStorageUnit()
                        .getFacility()
                        .getId()
        )) {
            throw new AppException(
                    ErrorCode.BOOKING_NOT_FOUND
            );
        }

        if (booking.getStatus() != BookingStatus.CONFIRMED) {
            throw new AppException(
                    ErrorCode.INVALID_REQUEST
            );
        }

        if (booking.getHandoverIssueStatus() == com.storehub.enums.HandoverIssueStatus.OPEN) {
            throw new AppException(ErrorCode.HANDOVER_ISSUE_RESOLUTION_REQUIRED);
        }
        if (booking.getHandoverIssueStatus() == com.storehub.enums.HandoverIssueStatus.ARRANGED
                && (booking.getHandoverIssueCustomerAgreedAt() == null
                    || booking.getScheduledCheckInTime() == null
                    || booking.getHandoverIssueDueAt() == null
                    || !booking.getHandoverIssueDueAt().isAfter(LocalDateTime.now()))) {
            throw new AppException(ErrorCode.HANDOVER_ISSUE_RESOLUTION_REQUIRED);
        }
        if (booking.getAssignedCheckInStaff() != null
                && !staff.getId().equals(booking.getAssignedCheckInStaff().getId())) {
            throw new AppException(ErrorCode.HANDOVER_ASSIGNED_TO_ANOTHER_STAFF);
        }

        // Chỉ bàn giao kho từ ngày bắt đầu thuê trở đi
        if (booking.getStartDate() != null
                && booking.getStartDate().isAfter(java.time.LocalDate.now())) {
            throw new AppException(ErrorCode.CHECKIN_TOO_EARLY);
        }
        if (booking.getEndDate() != null
                && !booking.getEndDate().isAfter(LocalDate.now())) {
            throw new AppException(ErrorCode.CHECKIN_RENTAL_ENDED);
        }
        if (!Boolean.TRUE.equals(booking.getUnitAssignmentConfirmed())) {
            throw new AppException(ErrorCode.UNIT_ASSIGNMENT_REQUIRED);
        }

        StorageUnit storageUnit = storageUnitRepository
                .lockById(booking.getStorageUnit().getId())
                .orElseThrow(() -> new AppException(
                        ErrorCode.STORAGE_UNIT_NOT_FOUND
                ));

        if (storageUnit.getStatus() != UnitStatus.RESERVED) {
            throw new AppException(
                    ErrorCode.INVALID_REQUEST
            );
        }

        // Ngăn/khóa hỏng, chưa sạch hoặc chưa khóa thì không bàn giao;
        // chuyển ngăn sang cần kiểm tra và trả đơn về cho quản lý.
        if (notReadyForHandover(request)) {
            return rejectHandover(booking, storageUnit, staff, request);
        }

        if (booking.getAssignedCheckOutStaff() == null) {
            booking.setAssignedCheckOutStaff(staff);
        }
        LocalDateTime now = LocalDateTime.now();

        HandoverRecord record = HandoverRecord.builder()
                .booking(booking)
                .staff(staff)
                .recordType("CHECK_IN")
                .unitCondition(buildUnitCondition(request))
                .notes(request.getNotes())
                .photos(request.getPhotos())
                .recordedAt(now)
                .build();

        handoverRecordRepository.save(record);

        booking.setStatus(BookingStatus.ACTIVE);
        booking.setHandedOverByStaffId(staff.getId());
        if (booking.getAssignedCheckInStaff() == null) {
            booking.setAssignedCheckInStaff(staff);
        }
        booking.setHandoverTime(now);
        if (booking.getHandoverIssueReportedAt() != null) {
            booking.setHandoverIssueStatus(com.storehub.enums.HandoverIssueStatus.RESOLVED);
        }

        storageUnit.setStatus(UnitStatus.OCCUPIED);

        bookingRepository.save(booking);
        storageUnitRepository.save(storageUnit);

        if (booking.getCustomer() != null) {
            notificationService.notifyUser(
                    booking.getCustomer(),
                    "Bàn giao kho thành công",
                    "Bạn đã nhận bàn giao ngăn kho " + storageUnit.getUnitCode()
                            + " tại " + storageUnit.getFacility().getName() + ". Chúc bạn có trải nghiệm lưu trữ thuận lợi!",
                    com.storehub.enums.NotificationType.CHECKIN_COMPLETED,
                    booking.getId(),
                    "BOOKING",
                    storageUnit.getFacility()
            );
        }

        return toHandoverResponse(
                booking,
                storageUnit,
                record,
                request.getLockCondition().getLabel(),
                staff,
                "Check-in completed successfully"
        );
    }

    @Override
    @Transactional(noRollbackFor = OutstandingOverdueFeeException.class)
    public HandoverResponse checkOut(
            UUID bookingId,
            UUID facilityId,
            String staffEmail,
            HandoverRequest request
    ) {
        validateHandoverConditions(request);
        User staff = facilityAccess.require(
                staffEmail,
                facilityId
        );

        Booking booking = bookingRepository
                .lockById(bookingId)
                .orElseThrow(() -> new AppException(
                        ErrorCode.BOOKING_NOT_FOUND
                ));

        if (booking.getStorageUnit() == null) {
            throw new AppException(
                    ErrorCode.STORAGE_UNIT_NOT_FOUND
            );
        }

        if (booking.getStorageUnit().getFacility() == null
                || !facilityId.equals(
                booking.getStorageUnit()
                        .getFacility()
                        .getId()
        )) {
            throw new AppException(
                    ErrorCode.BOOKING_NOT_FOUND
            );
        }

        if (booking.getStatus() != BookingStatus.ACTIVE) {
            throw new AppException(
                    ErrorCode.BOOKING_NOT_CHECKED_IN
            );
        }

        if (booking.getAssignedCheckOutStaff() != null
                && !staff.getId().equals(booking.getAssignedCheckOutStaff().getId())) {
            throw new AppException(ErrorCode.HANDOVER_ASSIGNED_TO_ANOTHER_STAFF);
        }

        StorageUnit storageUnit = storageUnitRepository
                .lockById(booking.getStorageUnit().getId())
                .orElseThrow(() -> new AppException(
                        ErrorCode.STORAGE_UNIT_NOT_FOUND
                ));

        if (storageUnit.getStatus() != UnitStatus.OCCUPIED) {
            throw new AppException(
                    ErrorCode.UNIT_UNAVAILABLE
            );
        }

        // Phí hư hại chỉ được trừ trong phạm vi tiền cọc đang giữ; kiểm tra trước khi đổi dữ liệu.
        BigDecimal damageFeeInput = request.getDamageFee();
        if (damageFeeInput != null) {
            BigDecimal depositHeld = booking.getDepositPaid() != null
                    ? booking.getDepositPaid() : BigDecimal.ZERO;
            if (damageFeeInput.signum() < 0 || damageFeeInput.compareTo(depositHeld) > 0) {
                throw new AppException(ErrorCode.DAMAGE_FEE_EXCEEDS_DEPOSIT);
            }
            if (damageFeeInput.signum() > 0
                    && (request.getDamageReason() == null || request.getDamageReason().isBlank())) {
                throw new AppException(ErrorCode.DAMAGE_REASON_REQUIRED);
            }
        }

        // Reconcile a missed nightly accrual under the booking lock. Commit the
        // new debt even when the return is rejected, so the customer can pay it.
        if (overdueScheduler.accrueOutstandingForCheckout(booking, LocalDateTime.now())) {
            throw new OutstandingOverdueFeeException();
        }

        // Nghiệm thu trả kho -> tạo yêu cầu hoàn cọc. Bị chặn nếu còn nợ phí trễ hạn.
        BigDecimal requestedRefund = (request.getDamageFee() != null || request.getDamageReason() != null)
                ? paymentService.refundDepositOnReturn(booking, request.getDamageFee(), request.getDamageReason())
                : paymentService.refundDepositOnReturn(booking);

        if (booking.getAssignedCheckOutStaff() == null) {
            booking.setAssignedCheckOutStaff(staff);
        }
        LocalDateTime now = LocalDateTime.now();

        HandoverRecord record = HandoverRecord.builder()
                .booking(booking)
                .staff(staff)
                .recordType("RETURN")
                .unitCondition(buildUnitCondition(request))
                .notes(request.getNotes())
                .damageFee(request.getDamageFee())
                .damageReason(request.getDamageReason())
                .photos(request.getPhotos())
                .recordedAt(now)
                .build();

        handoverRecordRepository.save(record);

        booking.setStatus(BookingStatus.COMPLETED);
        booking.setReturnTime(now);

        storageUnit.setStatus(UnitStatus.UNDER_MAINTENANCE);

        bookingRepository.save(booking);
        storageUnitRepository.save(storageUnit);

        String message;
        if (requestedRefund.signum() > 0) {
            message = "Check-out completed. Deposit refund requested: " + requestedRefund.toPlainString()
                    + (request.getDamageFee() != null && request.getDamageFee().signum() > 0
                        ? " (Damage fee deducted: " + request.getDamageFee().toPlainString() + ")" : "");
        } else if (request.getDamageFee() != null && request.getDamageFee().signum() > 0) {
            message = "Check-out completed. Deposit fully absorbed by damage fee (0 refund).";
        } else {
            message = "Check-out completed successfully";
        }

        com.storehub.entity.Facility facility = storageUnit.getFacility();
        String staffName = staff.getFullName() != null ? staff.getFullName() : staff.getUsername();
        String customerName = booking.getCustomer() != null && booking.getCustomer().getFullName() != null
                ? booking.getCustomer().getFullName() : "Khách hàng";
        String damageInfo = (request.getDamageFee() != null && request.getDamageFee().signum() > 0)
                ? " (Khấu trừ hư hại: " + request.getDamageFee().toPlainString() + " ₫, lý do: " + request.getDamageReason() + ")"
                : "";
        String noteInfo = (request.getNotes() != null && !request.getNotes().isBlank())
                ? " | Ghi chú: " + request.getNotes().trim() : "";
        String refundInfo = requestedRefund.signum() > 0
                ? " Khoản hoàn cọc: " + requestedRefund.toPlainString() + " ₫ đang chờ duyệt."
                : " Không phát sinh hoàn cọc.";

        notificationService.notifyFacilityManager(
                facility,
                "Nghiệm thu trả kho hoàn tất - Chờ duyệt hoàn cọc",
                "Nhân viên " + staffName + " đã nghiệm thu trả ngăn " + storageUnit.getUnitCode()
                        + " cho khách " + customerName + "." + damageInfo + noteInfo + refundInfo,
                com.storehub.enums.NotificationType.CHECKOUT_INSPECTED,
                booking.getId(),
                "BOOKING"
        );

        if (booking.getCustomer() != null) {
            String custRefundMsg = requestedRefund.signum() > 0
                    ? " Tiền cọc hoàn lại: " + requestedRefund.toPlainString() + " ₫" + damageInfo + ". Quản lý cơ sở sẽ tiến hành chuyển khoản hoàn tiền cho bạn."
                    : " Tiền cọc đã được khấu trừ toàn bộ cho chi phí hư hại/vệ sinh.";
            notificationService.notifyUser(
                    booking.getCustomer(),
                    "Nghiệm thu trả kho hoàn tất",
                    "Ngăn kho " + storageUnit.getUnitCode() + " đã hoàn tất nghiệm thu." + custRefundMsg,
                    com.storehub.enums.NotificationType.CHECKOUT_INSPECTED,
                    booking.getId(),
                    "BOOKING",
                    facility
            );
        }

        notificationService.notifyRole(
                "BUSINESS_MANAGER",
                "Nghiệm thu trả kho - " + (facility != null ? facility.getName() : ""),
                "Đơn " + booking.getBookingCode() + " (Ngăn " + storageUnit.getUnitCode() + ") tại "
                        + (facility != null ? facility.getName() : "") + " đã hoàn tất nghiệm thu trả kho." + refundInfo,
                com.storehub.enums.NotificationType.CHECKOUT_INSPECTED,
                booking.getId(),
                "BOOKING"
        );

        return toHandoverResponse(
                booking,
                storageUnit,
                record,
                request.getLockCondition().getLabel(),
                staff,
                message
        );
    }

    @Override
    @Transactional
    public String updateUnitStatus(
            UUID unitId,
            UUID facilityId,
            String staffEmail,
            UpdateUnitStatusRequest request
    ) {
        if (unitId == null
                || facilityId == null
                || request == null
                || request.getStatus() == null) {
            throw new AppException(
                    ErrorCode.INVALID_REQUEST
            );
        }

        facilityAccess.require(staffEmail, facilityId);

        StorageUnit storageUnit = storageUnitRepository
                .lockById(unitId)
                .orElseThrow(() -> new AppException(
                        ErrorCode.STORAGE_UNIT_NOT_FOUND
                ));

        if (storageUnit.getFacility() == null
                || !facilityId.equals(
                storageUnit.getFacility().getId()
        )) {
            throw new AppException(
                    ErrorCode.STORAGE_UNIT_NOT_FOUND
            );
        }

        UnitStatus current = storageUnit.getStatus();
        UnitStatus target = request.getStatus();

        // Cho phép: bảo trì -> trống (sau vệ sinh/kiểm tra) và
        // trống -> bảo trì (cần kiểm tra). Kho đang giữ chỗ/đang thuê
        // chỉ đổi trạng thái qua luồng booking (check-in / check-out).
        boolean validTransition =
                (current == UnitStatus.UNDER_MAINTENANCE && target == UnitStatus.AVAILABLE)
                        || (current == UnitStatus.AVAILABLE && target == UnitStatus.UNDER_MAINTENANCE);

        if (!validTransition) {
            throw new AppException(
                    ErrorCode.UNIT_UNAVAILABLE
            );
        }

        // Ngăn vừa kiểm tra xong nhưng vẫn là ngăn của một đơn đã xác nhận (đơn bị từ chối bàn giao,
        // đang chờ quản lý đổi ngăn): giữ chỗ cho đơn đó, không trả về trống để tránh bị đặt trùng.
        boolean heldForBooking = target == UnitStatus.AVAILABLE
                && bookingRepository.existsByStorageUnit_IdAndStatusIn(
                        unitId, List.of(BookingStatus.CONFIRMED));

        storageUnit.setStatus(heldForBooking ? UnitStatus.RESERVED : target);
        storageUnitRepository.save(storageUnit);

        if (target == UnitStatus.AVAILABLE
                && !heldForBooking
                && storageUnit.getUnitType() != null) {
            try {
                waitlistService.notifyNextInWaitlist(
                        facilityId,
                        storageUnit.getUnitType().getId()
                );
            } catch (Exception e) {
                log.warn("Failed to notify waitlist for unit {}: {}",
                        unitId, e.getMessage());
            }
        }

        return "Storage unit status updated successfully";
    }

    private void validateHandoverConditions(HandoverRequest request) {
        if (request == null || request.getUnitCondition() == null || request.getLockCondition() == null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
    }

    private boolean notReadyForHandover(HandoverRequest request) {
        return request.getUnitCondition() != com.storehub.enums.HandoverUnitCondition.GOOD
                || request.getLockCondition() != com.storehub.enums.HandoverLockCondition.LOCKED_WORKING;
    }

    private HandoverResponse rejectHandover(
            Booking booking,
            StorageUnit storageUnit,
            User staff,
            HandoverRequest request
    ) {
        if (request.getNotes() == null || request.getNotes().isBlank()) {
            throw new AppException(ErrorCode.HANDOVER_DEFECT_NOTE_REQUIRED);
        }

        if (booking.getAssignedCheckOutStaff() == null) {
            booking.setAssignedCheckOutStaff(staff);
        }
        LocalDateTime now = LocalDateTime.now();

        HandoverRecord record = HandoverRecord.builder()
                .booking(booking)
                .staff(staff)
                .recordType("CHECK_IN_REJECTED")
                .unitCondition(buildUnitCondition(request))
                .notes(request.getNotes())
                .photos(request.getPhotos())
                .recordedAt(now)
                .build();
        handoverRecordRepository.save(record);

        storageUnit.setStatus(UnitStatus.UNDER_MAINTENANCE);
        booking.setUnitAssignmentConfirmed(false);
        booking.setHandoverIssueStatus(com.storehub.enums.HandoverIssueStatus.OPEN);
        booking.setHandoverIssueReportedAt(now);
        booking.setHandoverIssueReason(request.getNotes().trim());
        booking.setHandoverIssueDueAt(now.plusHours(48));
        booking.setHandoverIssueCustomerAgreedAt(null);
        booking.setHandoverIssueResolvedBy(null);
        booking.setHandoverIssueResolutionNote(null);
        storageUnitRepository.save(storageUnit);
        bookingRepository.save(booking);

        com.storehub.entity.Facility defectFacility = storageUnit.getFacility();
        String defectStaffName = staff.getFullName() != null ? staff.getFullName() : staff.getUsername();

        notificationService.notifyFacilityManager(
                defectFacility,
                "Kho chưa hợp lệ để bàn giao",
                "Nhân viên " + defectStaffName + " báo cáo ngăn " + storageUnit.getUnitCode()
                        + " chưa đạt chuẩn để bàn giao cho khách (Đơn " + booking.getBookingCode() + "). "
                        + "Lý do: " + request.getNotes().trim() + ". Vui lòng kiểm tra bảo trì hoặc gán đổi ngăn khác cho khách.",
                com.storehub.enums.NotificationType.HANDOVER_DEFECT,
                booking.getId(),
                "BOOKING"
        );

        if (booking.getCustomer() != null) {
            notificationService.notifyUser(
                    booking.getCustomer(),
                    "Ngăn kho đang được xử lý kỹ thuật",
                    "Ngăn kho " + storageUnit.getUnitCode() + " đang được nhân viên cơ sở kiểm tra bảo trì trước khi bàn giao. "
                            + "Quản lý cơ sở sẽ hỗ trợ sắp xếp/đổi ngăn phù hợp nhất cho bạn trong ít phút.",
                    com.storehub.enums.NotificationType.HANDOVER_DEFECT,
                    booking.getId(),
                    "BOOKING",
                    defectFacility
            );
        }

        notificationService.notifyRole(
                "BUSINESS_MANAGER",
                "Sự cố bàn giao kho - " + (defectFacility != null ? defectFacility.getName() : ""),
                "Cơ sở " + (defectFacility != null ? defectFacility.getName() : "") + ": Ngăn " + storageUnit.getUnitCode()
                        + " không đủ điều kiện bàn giao cho đơn " + booking.getBookingCode() + ". Lý do: " + request.getNotes().trim(),
                com.storehub.enums.NotificationType.HANDOVER_DEFECT,
                booking.getId(),
                "BOOKING"
        );

        return toHandoverResponse(
                booking,
                storageUnit,
                record,
                request.getLockCondition().getLabel(),
                staff,
                "Ngăn " + storageUnit.getUnitCode()
                        + " chưa thể bàn giao và đã chuyển sang trạng thái cần kiểm tra/bảo trì. "
                        + "Đơn của khách được trả về cho quản lý để đổi sang ngăn khác."
        );
    }

    private String buildUnitCondition(
            HandoverRequest request
    ) {
        return "Unit: "
                + request.getUnitCondition().getLabel()
                + " | Lock: "
                + request.getLockCondition().getLabel();
    }

    private LocalDateTime checkInTime(Booking booking) {
        if (booking.getScheduledCheckInTime() != null) {
            return booking.getScheduledCheckInTime();
        }
        return booking.getStartDate().atTime(
                booking.getStorageUnit().getFacility().getOpenTime() != null
                        ? booking.getStorageUnit().getFacility().getOpenTime()
                        : java.time.LocalTime.of(8, 0));
    }

    private boolean visibleToStaff(User viewer, User assigned) {
        return viewer.getRole() == null || !"STAFF".equals(viewer.getRole().getName())
                || assigned == null || viewer.getId().equals(assigned.getId());
    }

    private DailyScheduleResponse toScheduleResponse(
            Booking booking,
            String scheduleType,
            LocalDateTime scheduledTime
    ) {
        StorageUnit storageUnit = booking.getStorageUnit();

        UUID customerId = null;
        String customerName = null;
        String customerEmail = null;

        if (booking.getCustomer() != null) {
            customerId = booking.getCustomer().getId();
            customerName = booking.getCustomer().getFullName();
            customerEmail = booking.getCustomer().getEmail();
        }

        UUID facilityId = null;
        String facilityName = null;

        if (storageUnit != null
                && storageUnit.getFacility() != null) {
            facilityId = storageUnit.getFacility().getId();
            facilityName = storageUnit.getFacility().getName();
        }

        String unitType = null;

        if (storageUnit != null
                && storageUnit.getUnitType() != null) {
            unitType = storageUnit.getUnitType().getTypeName();
        }

        User assigned = "CHECK_IN".equals(scheduleType)
                ? booking.getAssignedCheckInStaff() : booking.getAssignedCheckOutStaff();
        return DailyScheduleResponse.builder()
                .bookingId(booking.getId())
                .bookingCode(booking.getBookingCode())
                .customerId(customerId)
                .customerName(customerName)
                .customerEmail(customerEmail)
                .facilityId(facilityId)
                .facilityName(facilityName)
                .storageUnitId(
                        storageUnit != null
                                ? storageUnit.getId()
                                : null
                )
                .unitCode(
                        storageUnit != null
                                ? storageUnit.getUnitCode()
                                : null
                )
                .floorLevel(
                        storageUnit != null
                                ? storageUnit.getFloorLevel()
                                : null
                )
                .type(unitType)
                .scheduledTime(scheduledTime)
                .scheduleType(scheduleType)
                .assignedStaffId(assigned != null ? assigned.getId() : null)
                .assignedStaffName(assigned != null ? assigned.getFullName() : null)
                .bookingStatus(booking.getStatus())
                .unitAssignmentConfirmed(Boolean.TRUE.equals(booking.getUnitAssignmentConfirmed()))
                .build();
    }

    private HandoverResponse toHandoverResponse(
            Booking booking,
            StorageUnit storageUnit,
            HandoverRecord record,
            String lockCondition,
            User staff,
            String message
    ) {
        return HandoverResponse.builder()
                .bookingId(booking.getId())
                .bookingCode(booking.getBookingCode())
                .storageUnitId(storageUnit.getId())
                .unitCode(storageUnit.getUnitCode())
                .recordType(record.getRecordType())
                .unitCondition(record.getUnitCondition())
                .lockCondition(lockCondition)
                .notes(record.getNotes())
                .bookingStatus(booking.getStatus())
                .unitStatus(storageUnit.getStatus().name())
                .staffId(staff.getId())
                .staffName(staff.getFullName())
                .damageFee(record.getDamageFee())
                .damageReason(record.getDamageReason())
                .recordedAt(record.getRecordedAt())
                .message(message)
                .build();
    }

    @Override
    public List<String> uploadHandoverPhotos(org.springframework.web.multipart.MultipartFile[] files) {
        if (files == null || files.length == 0) {
            return java.util.Collections.emptyList();
        }
        List<String> urls = new ArrayList<>();
        for (org.springframework.web.multipart.MultipartFile file : files) {
            if (file != null && !file.isEmpty()) {
                urls.add(cloudinaryService.uploadImage(file, "handover"));
            }
        }
        return urls;
    }
}
