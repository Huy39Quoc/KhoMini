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
public class FacilityOperationsServiceImpl
        implements FacilityOperationsService {

    private final BookingRepository bookingRepository;
    private final HandoverRecordRepository handoverRecordRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final FacilityAccess facilityAccess;

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
                "Check-out completed successfully"
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

        if (storageUnit.getStatus() != UnitStatus.UNDER_MAINTENANCE
                || request.getStatus() != UnitStatus.AVAILABLE) {
            throw new AppException(
                    ErrorCode.UNIT_UNAVAILABLE
            );
        }

        storageUnit.setStatus(UnitStatus.AVAILABLE);
        storageUnitRepository.save(storageUnit);

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