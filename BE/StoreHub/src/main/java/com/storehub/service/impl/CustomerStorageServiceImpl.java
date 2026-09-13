package com.storehub.service.impl;

import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.SmartAccessResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.UnitType;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.service.CustomerStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
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

    @Override
    @Transactional
    public SmartAccessResponse getSmartAccessInfo(Long bookingId, UUID customerId) {
        Booking booking = validateActiveBooking(bookingId, customerId);

        // Nếu đơn thuê chưa có mã PIN, tự động sinh mã PIN 6 số ngẫu nhiên ban đầu
        if (booking.getAccessPin() == null || booking.getAccessPin().isBlank()) {
            booking.setAccessPin(generateRandomPin());
            booking.setPinUpdatedAt(LocalDateTime.now());
        }

        // Tạo chuỗi token QR Code ngắn hạn (ví dụ có hiệu lực trong 5 phút)
        String qrToken = "ACCESS:" + booking.getId() + ":" + UUID.randomUUID() + ":" + System.currentTimeMillis();
        booking.setQrAccessToken(qrToken);
        bookingRepository.save(booking);

        return SmartAccessResponse.builder()
                .bookingId(booking.getId())
                .unitCode(booking.getStorageUnit() != null ? booking.getStorageUnit().getUnitCode() : "Chờ phân bổ")
                .accessPin(booking.getAccessPin())
                .qrCodeToken(qrToken)
                .pinUpdatedAt(booking.getPinUpdatedAt())
                .tokenExpiresAt(LocalDateTime.now().plusMinutes(5))
                .build();
    }

    @Override
    @Transactional
    public SmartAccessResponse updateAccessPin(Long bookingId, UUID customerId, UpdatePinRequest request) {
        Booking booking = validateActiveBooking(bookingId, customerId);

        // Chiều DTO -> Entity: Gán mã PIN mới từ DTO vào thực thể Booking
        booking.setAccessPin(request.getNewPin());
        booking.setPinUpdatedAt(LocalDateTime.now());
        bookingRepository.save(booking);

        return SmartAccessResponse.builder()
                .bookingId(booking.getId())
                .unitCode(booking.getStorageUnit() != null ? booking.getStorageUnit().getUnitCode() : "Chờ phân bổ")
                .accessPin(booking.getAccessPin())
                .qrCodeToken(booking.getQrAccessToken())
                .pinUpdatedAt(booking.getPinUpdatedAt())
                .tokenExpiresAt(LocalDateTime.now().plusMinutes(5))
                .build();
    }

    // Hàm kiểm tra hợp lệ: Đơn thuê phải tồn tại, thuộc khách hàng và đã CHECKED_IN
    private Booking validateActiveBooking(Long bookingId, UUID customerId) {
        Booking booking = bookingRepository.findByIdAndCustomerId(bookingId, customerId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        if (booking.getStatus() != BookingStatus.ACTIVE) {
            throw new AppException(ErrorCode.FORBIDDEN); // Chỉ cho phép mở khóa khi đã check-in
        }
        return booking;
    }

    private String generateRandomPin() {
        SecureRandom random = new SecureRandom();
        int num = 100000 + random.nextInt(900000);
        return String.valueOf(num);
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