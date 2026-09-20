package com.storehub.service.impl;

import com.storehub.dto.request.HandoverRequest;
import com.storehub.dto.request.UpdateUnitStatusRequest;
import com.storehub.dto.response.DailyScheduleResponse;
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
import com.storehub.repository.UserRepository;
import com.storehub.service.FacilityOperationsService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class FacilityOperationsServiceImpl implements FacilityOperationsService {

    private final BookingRepository bookingRepository;
    private final HandoverRecordRepository handoverRecordRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final UserRepository userRepository;

    @Override
    @Transactional(readOnly = true)
    public List<DailyScheduleResponse> getDailySchedule(
            UUID facilityId,
            LocalDate date
    ) {

        if (facilityId == null || date == null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        List<DailyScheduleResponse> result = new ArrayList<>();

        // Customer check-in trong ngày
        List<Booking> checkInBookings = bookingRepository.findCheckInSchedule(
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

        // Customer check-out trong ngày
        LocalDateTime startOfDay = date.atStartOfDay();
        LocalDateTime endOfDay = date.plusDays(1).atStartOfDay();

        List<Booking> checkOutBookings = bookingRepository.findCheckOutSchedule(
                facilityId,
                BookingStatus.ACTIVE,
                startOfDay,
                endOfDay
        );

        for (Booking booking : checkOutBookings) {
            result.add(toScheduleResponse(
                    booking,
                    "CHECK_OUT",
                    booking.getReturnTime()
            ));
        }

        result.sort(
                Comparator.comparing(
                        DailyScheduleResponse::getScheduledTime,
                        Comparator.nullsLast(Comparator.naturalOrder())
                )
        );

        return result;
    }

    @Override
    @Transactional
    public HandoverResponse checkIn(
            UUID bookingId,
            UUID facilityId,
            String staffEmail,
            HandoverRequest request
    ) {

        Booking booking = bookingRepository
                .findByIdAndFacilityId(bookingId, facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        if (booking.getStatus() != BookingStatus.CONFIRMED) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        if (booking.getStorageUnit() == null) {
            throw new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND);
        }

        StorageUnit storageUnit = booking.getStorageUnit();

        // Storage unit phải đang ở trạng thái RESERVED mới được check-in
        if (storageUnit.getStatus() != UnitStatus.RESERVED) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        User staff = userRepository
                .findByEmail(staffEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

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

        // Update booking
        booking.setStatus(BookingStatus.ACTIVE);
        booking.setHandedOverByStaffId(staff.getId());
        booking.setHandoverTime(now);

        // Update storage unit
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

        Booking booking = bookingRepository
                .findByIdAndFacilityId(bookingId, facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        if (booking.getStatus() != BookingStatus.ACTIVE) {
            throw new AppException(ErrorCode.BOOKING_NOT_CHECKED_IN);
        }

        if (booking.getStorageUnit() == null) {
            throw new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND);
        }

        StorageUnit storageUnit = booking.getStorageUnit();

        User staff = userRepository
                .findByEmail(staffEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

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

        // Update booking
        booking.setStatus(BookingStatus.COMPLETED);

        if (booking.getReturnTime() == null) {
            booking.setReturnTime(now);
        }

        // Sau khi customer trả storage,
        // unit chuyển sang UNDER_MAINTENANCE để staff kiểm tra
        storageUnit.setStatus(UnitStatus.UNDER_MAINTENANCE);

        bookingRepository.save(booking);
        storageUnitRepository.save(storageUnit);

        return toHandoverResponse(
                booking,
                storageUnit,
                record,
                request.getLockCondition(),
                staff,
                "Check-out completed successfully"
        );
    }

    @Override
    @Transactional
    public String updateUnitStatus(
            UUID unitId,
            UUID facilityId,
            UpdateUnitStatusRequest request
    ) {

        if (unitId == null || facilityId == null || request == null
                || request.getStatus() == null) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        StorageUnit storageUnit = storageUnitRepository
                .findWithDetailsById(unitId)
                .orElseThrow(() -> new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND));

        if (storageUnit.getFacility() == null
                || !facilityId.equals(storageUnit.getFacility().getId())) {
            throw new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND);
        }

        storageUnit.setStatus(request.getStatus());

        storageUnitRepository.save(storageUnit);

        return "Storage unit status updated successfully";
    }

    private String buildUnitCondition(HandoverRequest request) {

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

        String customerName = null;
        String customerEmail = null;
        UUID customerId = null;

        if (booking.getCustomer() != null) {
            customerId = booking.getCustomer().getId();
            customerName = booking.getCustomer().getFullName();
            customerEmail = booking.getCustomer().getEmail();
        }

        String facilityName = null;
        UUID facilityId = null;

        if (storageUnit != null && storageUnit.getFacility() != null) {
            facilityId = storageUnit.getFacility().getId();
            facilityName = storageUnit.getFacility().getName();
        }

        String unitType = null;

        if (storageUnit != null && storageUnit.getUnitType() != null) {
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