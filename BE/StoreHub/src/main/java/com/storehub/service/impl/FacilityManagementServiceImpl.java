package com.storehub.service.impl;

import com.storehub.dto.request.FacilityUnitRequest;
import com.storehub.dto.response.AssignedFacilityResponse;
import com.storehub.dto.response.FacilityReportResponse;
import com.storehub.dto.response.FacilityStaffResponse;
import com.storehub.dto.response.FacilityUnitResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.UnitType;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UnitTypeRepository;
import com.storehub.repository.UserRepository;
import com.storehub.entity.FacilityAccess;
import com.storehub.service.FacilityManagementService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class FacilityManagementServiceImpl
        implements FacilityManagementService {

    private final FacilityAccess access;
    private final FacilityRepository facilities;
    private final StorageUnitRepository units;
    private final UnitTypeRepository types;
    private final BookingRepository bookings;
    private final UserRepository users;

    @Transactional(readOnly = true)
    public AssignedFacilityResponse myFacility(String email) {
        User user = users.findByEmail(email)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        if (user.getFacility() == null) {
            throw new AppException(ErrorCode.FORBIDDEN);
        }

        Facility facility = user.getFacility();

        return new AssignedFacilityResponse(
                facility.getId(),
                facility.getName(),
                facility.getAddress()
        );
    }

    @Transactional(readOnly = true)
    public List<FacilityUnitResponse> units(
            UUID facilityId,
            String managerEmail
    ) {
        access.require(managerEmail, facilityId);
        requireFacility(facilityId);

        return units.findByFacility_IdOrderByUnitCodeAsc(facilityId)
                .stream()
                .map(this::toUnit)
                .toList();
    }

    @Transactional
    public FacilityUnitResponse createUnit(
            UUID facilityId,
            String managerEmail,
            FacilityUnitRequest request
    ) {
        access.require(managerEmail, facilityId);

        Facility facility = requireFacility(facilityId);
        String code = request.unitCode().trim();

        if (units.existsByFacility_IdAndUnitCode(facilityId, code)) {
            throw new AppException(ErrorCode.UNIT_CODE_EXISTED);
        }

        UnitType type = types.findById(request.unitTypeId())
                .orElseThrow(() -> new AppException(ErrorCode.UNIT_TYPE_NOT_FOUND));

        StorageUnit unit = StorageUnit.builder()
                .facility(facility)
                .unitType(type)
                .unitCode(code)
                .floorLevel(request.floorLevel())
                .status(UnitStatus.AVAILABLE)
                .build();

        return toUnit(units.save(unit));
    }

    @Transactional
    public FacilityUnitResponse updateUnit(
            UUID facilityId,
            UUID unitId,
            String managerEmail,
            FacilityUnitRequest request
    ) {
        access.require(managerEmail, facilityId);

        StorageUnit unit = units.lockById(unitId)
                .orElseThrow(() -> new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND));

        requireUnitFacility(unit, facilityId);

        boolean hasOpenBooking =
                bookings.existsByStorageUnit_IdAndStatusIn(
                        unitId,
                        List.of(
                                BookingStatus.PENDING_PAYMENT,
                                BookingStatus.CONFIRMED,
                                BookingStatus.ACTIVE
                        )
                );

        if (unit.getStatus() != UnitStatus.AVAILABLE || hasOpenBooking) {
            throw new AppException(ErrorCode.UNIT_UNAVAILABLE);
        }

        String code = request.unitCode().trim();

        if (!unit.getUnitCode().equals(code)
                && units.existsByFacility_IdAndUnitCode(facilityId, code)) {
            throw new AppException(ErrorCode.UNIT_CODE_EXISTED);
        }

        UnitType type = types.findById(request.unitTypeId())
                .orElseThrow(() -> new AppException(ErrorCode.UNIT_TYPE_NOT_FOUND));

        unit.setUnitCode(code);
        unit.setFloorLevel(request.floorLevel());
        unit.setUnitType(type);

        return toUnit(unit);
    }

    @Transactional
    public FacilityUnitResponse assignUnit(
            UUID facilityId,
            UUID bookingId,
            UUID unitId,
            String managerEmail
    ) {
        access.require(managerEmail, facilityId);

        Booking booking = bookings.lockById(bookingId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        StorageUnit oldUnit = booking.getStorageUnit();

        if (oldUnit == null
                || oldUnit.getFacility() == null
                || !facilityId.equals(oldUnit.getFacility().getId())) {
            throw new AppException(ErrorCode.BOOKING_NOT_FOUND);
        }

        if (booking.getStatus() != BookingStatus.CONFIRMED
                || oldUnit.getStatus() != UnitStatus.RESERVED) {
            throw new AppException(ErrorCode.UNIT_UNAVAILABLE);
        }

        if (oldUnit.getId().equals(unitId)) {
            return toUnit(oldUnit);
        }

        StorageUnit replacement = units.lockById(unitId)
                .orElseThrow(() -> new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND));

        requireUnitFacility(replacement, facilityId);

        boolean sameType = replacement.getUnitType() != null
                && oldUnit.getUnitType() != null
                && replacement.getUnitType().getId()
                .equals(oldUnit.getUnitType().getId());

        if (!sameType || replacement.getStatus() != UnitStatus.AVAILABLE) {
            throw new AppException(ErrorCode.UNIT_UNAVAILABLE);
        }

        replacement.setStatus(UnitStatus.RESERVED);
        booking.setStorageUnit(replacement);
        oldUnit.setStatus(UnitStatus.AVAILABLE);

        return toUnit(replacement);
    }

    @Transactional(readOnly = true)
    public FacilityReportResponse report(
            UUID facilityId,
            String managerEmail
    ) {
        access.require(managerEmail, facilityId);
        requireFacility(facilityId);

        List<StorageUnit> all =
                units.findByFacility_IdOrderByUnitCodeAsc(facilityId);

        long available = all.stream()
                .filter(u -> u.getStatus() == UnitStatus.AVAILABLE)
                .count();

        long reserved = all.stream()
                .filter(u -> u.getStatus() == UnitStatus.RESERVED)
                .count();

        long occupied = all.stream()
                .filter(u -> u.getStatus() == UnitStatus.OCCUPIED)
                .count();

        long maintenance = all.stream()
                .filter(u -> u.getStatus() == UnitStatus.UNDER_MAINTENANCE)
                .count();

        double occupancyRate = all.isEmpty()
                ? 0
                : 100.0 * occupied / all.size();

        return new FacilityReportResponse(
                facilityId,
                all.size(),
                available,
                reserved,
                occupied,
                maintenance,
                occupancyRate
        );
    }

    @Transactional
    public FacilityStaffResponse assignPerson(
            UUID facilityId,
            UUID userId,
            String role,
            String managerEmail
    ) {
        if (managerEmail != null) {
            access.require(managerEmail, facilityId);
        }

        Facility facility = requireFacility(facilityId);

        User user = users.findById(userId)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        if (!Boolean.TRUE.equals(user.getIsActive())
                || user.getRole() == null
                || !role.equals(user.getRole().getName())) {
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }

        if (managerEmail != null
                && user.getFacility() != null
                && !facilityId.equals(user.getFacility().getId())) {
            throw new AppException(ErrorCode.FORBIDDEN);
        }

        user.setFacility(facility);

        return new FacilityStaffResponse(
                user.getId(),
                user.getFullName(),
                user.getEmail(),
                role
        );
    }

    @Transactional(readOnly = true)
    public List<FacilityStaffResponse> staff(
            UUID facilityId,
            String managerEmail
    ) {
        access.require(managerEmail, facilityId);
        requireFacility(facilityId);

        return users.findByFacility_IdAndRole_Name(facilityId, "STAFF")
                .stream()
                .map(user -> new FacilityStaffResponse(
                        user.getId(),
                        user.getFullName(),
                        user.getEmail(),
                        "STAFF"
                ))
                .toList();
    }

    private Facility requireFacility(UUID facilityId) {
        return facilities.findById(facilityId)
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));
    }

    private void requireUnitFacility(
            StorageUnit unit,
            UUID facilityId
    ) {
        if (unit.getFacility() == null
                || !facilityId.equals(unit.getFacility().getId())) {
            throw new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND);
        }
    }

    private FacilityUnitResponse toUnit(StorageUnit unit) {
        return new FacilityUnitResponse(
                unit.getId(),
                unit.getUnitCode(),
                unit.getFloorLevel(),
                unit.getUnitType().getId(),
                unit.getUnitType().getTypeName(),
                unit.getStatus()
        );
    }
}