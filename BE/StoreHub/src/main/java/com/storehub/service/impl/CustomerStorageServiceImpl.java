package com.storehub.service.impl;

import com.storehub.dto.response.MyUnitResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.UnitType;
import com.storehub.enums.BookingStatus;
import com.storehub.repository.BookingRepository;
import com.storehub.service.CustomerStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CustomerStorageServiceImpl implements CustomerStorageService {

    private final BookingRepository bookingRepository;

    @Override
    @Transactional(readOnly = true)
    public List<MyUnitResponse> getMyRentedUnits(UUID customerId) {
        List<BookingStatus> activeStatuses = Arrays.asList(
                BookingStatus.CONFIRMED,
                BookingStatus.ACTIVE
        );

        List<Booking> bookings = bookingRepository.findActiveBookingsByCustomerId(customerId, activeStatuses);

        return bookings.stream().map(this::mapToResponse).collect(Collectors.toList());
    }

    private MyUnitResponse mapToResponse(Booking b) {
        StorageUnit unit = b.getStorageUnit();
        Facility facility = (unit != null) ? unit.getFacility() : null;
        UnitType unitType = (unit != null) ? unit.getUnitType() : null;

        return MyUnitResponse.builder()
                .bookingId(b.getId())
                .bookingCode(b.getBookingCode())
                .facilityName(facility != null ? facility.getName() : "Chưa xác định cơ sở")
                .facilityAddress(facility != null ? facility.getAddress() : "")
                .unitCode(unit != null ? unit.getUnitCode() : "Chờ phân bổ")
                .unitTypeName(unitType != null ? unitType.getTypeName() : "")
                .dimensions(unitType != null ? unitType.getDimensions() : "")
                .areaSqm(unitType != null ? unitType.getAreaSqm() : null)
                .startDate(b.getStartDate())
                .endDate(b.getEndDate())
                .rentalMonths(b.getRentalMonths())
                .status(b.getStatus())
                .totalRentalFee(b.getTotalRentalFee())
                .depositPaid(b.getDepositPaid())
                .hasActiveAccess(b.getStatus() == BookingStatus.ACTIVE)
                .build();
    }
}