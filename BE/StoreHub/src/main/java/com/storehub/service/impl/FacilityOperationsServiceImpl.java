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
import com.storehub.repository.BookingRepository;
import com.storehub.repository.HandoverRecordRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.entity.FacilityAccess;
import com.storehub.service.FacilityOperationsService;
import com.storehub.service.PaymentService;
import com.storehub.service.WaitlistService;

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
    private final FacilityAccess facilityAccess;
    private final PaymentService paymentService;
    private final WaitlistService waitlistService;
    private final org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;
    private final com.storehub.service.ActivityLogService activityLogService;

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

        facilityAccess.require(staffEmail, facilityId);

        List<DailyScheduleResponse> result = new ArrayList<>();

        List<Booking> checkInBookings =
                bookingRepository.findCheckInSchedule(
                        facilityId,
                        BookingStatus.CONFIRMED,
                        date
                );

        for (Booking booking : checkInBookings) {
            result.add(toScheduleResponse(
                    booking,
                    "CHECK_IN",
                    booking.getStartDate().atStartOfDay()
            ));
        }

        LocalDateTime startOfDay = date.atStartOfDay();
        LocalDateTime endOfDay = date.plusDays(1).atStartOfDay();

        List<Booking> checkOutBookings =
                bookingRepository.findCheckOutSchedule(
                        facilityId,
                        BookingStatus.ACTIVE,
                        endOfDay,
                        date
                );

        for (Booking booking : checkOutBookings) {
            // Khách đã hẹn trả kho: theo giờ hẹn. Khách chưa hẹn nhưng hợp đồng
            // đã đến/quá hạn: theo ngày hết hạn.
            LocalDateTime scheduled = booking.getScheduledReturnTime() != null
                    ? booking.getScheduledReturnTime()
                    : booking.getEndDate().atStartOfDay();

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
                        record.getRecordedAt()
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

        // Chỉ bàn giao kho từ ngày bắt đầu thuê trở đi
        if (booking.getStartDate() != null
                && booking.getStartDate().isAfter(java.time.LocalDate.now())) {
            throw new AppException(ErrorCode.CHECKIN_TOO_EARLY);
        }
        if (booking.getEndDate() != null
                && !booking.getEndDate().isAfter(LocalDate.now())) {
            throw new AppException(ErrorCode.CHECKIN_RENTAL_ENDED);
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

        LocalDateTime now = LocalDateTime.now();

        HandoverRecord record = HandoverRecord.builder()
                .booking(booking)
                .staff(staff)
                .recordType("CHECK_IN")
                .unitCondition(buildUnitCondition(request))
                .notes(request.getNotes())
                .recordedAt(now)
                .build();

        handoverRecordRepository.save(record);

        booking.setStatus(BookingStatus.ACTIVE);
        booking.setHandedOverByStaffId(staff.getId());
        booking.setHandoverTime(now);

        storageUnit.setStatus(UnitStatus.OCCUPIED);

        bookingRepository.save(booking);
        storageUnitRepository.save(storageUnit);

        return toHandoverResponse(
                booking,
                storageUnit,
                record,
                request.getLockCondition(),
                staff,
                "Check-in completed successfully"
        );
    }

    @Override
    @Transactional
    public HandoverResponse checkOut(
            UUID bookingId,
            UUID facilityId,
            String staffEmail,
            HandoverRequest request
    ) {
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

        // Nghiệm thu trả kho -> hoàn cọc. Bị chặn nếu khách còn nợ phí trễ hạn.
        BigDecimal refundedDeposit = paymentService.refundDepositOnReturn(booking);

        LocalDateTime now = LocalDateTime.now();

        HandoverRecord record = HandoverRecord.builder()
                .booking(booking)
                .staff(staff)
                .recordType("RETURN")
                .unitCondition(buildUnitCondition(request))
                .notes(request.getNotes())
                .recordedAt(now)
                .build();

        handoverRecordRepository.save(record);

        booking.setStatus(BookingStatus.COMPLETED);
        booking.setReturnTime(now);

        storageUnit.setStatus(UnitStatus.UNDER_MAINTENANCE);

        bookingRepository.save(booking);
        storageUnitRepository.save(storageUnit);

        return toHandoverResponse(
                booking,
                storageUnit,
                record,
                request.getLockCondition(),
                staff,
                refundedDeposit.signum() > 0
                        ? "Check-out completed successfully. Deposit refunded: "
                        + refundedDeposit.toPlainString()
                        : "Check-out completed successfully"
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

        storageUnit.setStatus(target);
        storageUnitRepository.save(storageUnit);

        if (target == UnitStatus.AVAILABLE
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

    private String buildUnitCondition(
            HandoverRequest request
    ) {
        return "Unit: "
                + request.getUnitCondition()
                + " | Lock: "
                + request.getLockCondition();
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
                .bookingStatus(booking.getStatus())
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
                .recordedAt(record.getRecordedAt())
                .message(message)
                .build();
    }
}
