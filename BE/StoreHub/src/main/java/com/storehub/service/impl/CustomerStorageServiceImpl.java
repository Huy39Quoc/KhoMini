package com.storehub.service.impl;

import com.storehub.dto.request.CheckoutRequest;
import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.ContractOperationResponse;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.SmartAccessResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.UnitType;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.UserRepository;
import com.storehub.enums.ActivityAction;
import com.storehub.service.ActivityLogService;
import com.storehub.service.CustomerStorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CustomerStorageServiceImpl implements CustomerStorageService {

    private final BookingRepository bookingRepository;
    private final UserRepository userRepository;
    private final ActivityLogService activityLogService;

    @Override
    @Transactional(readOnly = true)
    public List<MyUnitResponse> getMyRentedUnits(String customerEmail) {
        UUID customerId = resolveCustomerId(customerEmail);

        List<BookingStatus> activeStatuses = Arrays.asList(
                BookingStatus.CONFIRMED,
                BookingStatus.ACTIVE
        );

        List<Booking> bookings = bookingRepository.findActiveBookingsByCustomerId(customerId, activeStatuses);
        return bookings.stream().map(this::mapToResponse).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public SmartAccessResponse getSmartAccessInfo(UUID bookingId, String customerEmail) {
        Booking booking = validateActiveBooking(bookingId, resolveCustomerId(customerEmail));

        boolean isNewPin = false;
        if (booking.getAccessPin() == null || booking.getAccessPin().isBlank()) {
            booking.setAccessPin(generateRandomPin());
            booking.setPinUpdatedAt(LocalDateTime.now());
            isNewPin = true;
        }

        String qrToken = "ACCESS:" + booking.getId() + ":" + UUID.randomUUID() + ":" + System.currentTimeMillis();
        booking.setQrAccessToken(qrToken);
        bookingRepository.save(booking);

        if (isNewPin) {
            UUID customerId = resolveCustomerId(customerEmail);
            activityLogService.record(customerId, ActivityAction.ACCESS_CREDENTIAL_ISSUE, "BOOKING", booking.getId(),
                    "Issued initial access PIN for booking " + booking.getBookingCode(), null, null);
        }

        return SmartAccessResponse.builder()
                .bookingId(booking.getId())
                .unitCode(booking.getStorageUnit() != null ? booking.getStorageUnit().getUnitCode() : "Unassigned")
                .accessPin(booking.getAccessPin())
                .qrCodeToken(qrToken)
                .pinUpdatedAt(booking.getPinUpdatedAt())
                .tokenExpiresAt(LocalDateTime.now().plusMinutes(5))
                .build();
    }

    @Override
    @Transactional
    public SmartAccessResponse updateAccessPin(UUID bookingId, String customerEmail, UpdatePinRequest request) {
        Booking booking = validateActiveBooking(bookingId, resolveCustomerId(customerEmail));

        booking.setAccessPin(request.getNewPin());
        booking.setPinUpdatedAt(LocalDateTime.now());
        bookingRepository.save(booking);

        UUID customerId = resolveCustomerId(customerEmail);
        activityLogService.record(customerId, ActivityAction.ACCESS_CREDENTIAL_UPDATE, "BOOKING", booking.getId(),
                "Updated access PIN for booking " + booking.getBookingCode(), null, null);

        return SmartAccessResponse.builder()
                .bookingId(booking.getId())
                .unitCode(booking.getStorageUnit() != null ? booking.getStorageUnit().getUnitCode() : "Unassigned")
                .accessPin(booking.getAccessPin())
                .qrCodeToken(booking.getQrAccessToken())
                .pinUpdatedAt(booking.getPinUpdatedAt())
                .tokenExpiresAt(LocalDateTime.now().plusMinutes(5))
                .build();
    }

    @Override
    @Transactional
    public ContractOperationResponse extendRental(UUID bookingId, String customerEmail, ExtendRentalRequest request) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);

        LocalDate oldEndDate = booking.getEndDate();
        int extraMonths = request.getExtraMonths();

        LocalDate newEndDate = oldEndDate.plusMonths(extraMonths);

        BigDecimal monthlyPrice = BigDecimal.ZERO;
        if (booking.getStorageUnit() != null && booking.getStorageUnit().getUnitType() != null) {
            monthlyPrice = booking.getStorageUnit().getUnitType().getBasePricePerMonth();
        }
        BigDecimal additionalFee = monthlyPrice.multiply(BigDecimal.valueOf(extraMonths));

        booking.setEndDate(newEndDate);
        booking.setRentalMonths(booking.getRentalMonths() + extraMonths);
        booking.setTotalRentalFee(booking.getTotalRentalFee().add(additionalFee));

        bookingRepository.save(booking);

        activityLogService.record(customerId, ActivityAction.CONTRACT_EXTENDED, "BOOKING", booking.getId(),
                "Extended rental for booking " + booking.getBookingCode() + " by " + extraMonths + " month(s) until " + newEndDate,
                oldEndDate, newEndDate);

        return ContractOperationResponse.builder()
                .bookingId(booking.getId())
                .bookingCode(booking.getBookingCode())
                .status(booking.getStatus())
                .oldEndDate(oldEndDate)
                .newEndDate(newEndDate)
                .totalRentalMonths(booking.getRentalMonths())
                .additionalFee(additionalFee)
                .updatedTotalFee(booking.getTotalRentalFee())
                .message("Rental extension completed successfully for " + extraMonths + " month(s)")
                .build();
    }

    @Override
    @Transactional
    public ContractOperationResponse requestCheckout(UUID bookingId, String customerEmail, CheckoutRequest request) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);

        booking.setReturnTime(request.getScheduledReturnTime());
        bookingRepository.save(booking);

        activityLogService.record(customerId, ActivityAction.CHECKOUT_REQUEST, "BOOKING", booking.getId(),
                "Requested checkout for booking " + booking.getBookingCode() + " at " + request.getScheduledReturnTime(),
                null, request.getScheduledReturnTime());

        return ContractOperationResponse.builder()
                .bookingId(booking.getId())
                .bookingCode(booking.getBookingCode())
                .status(booking.getStatus())
                .scheduledReturnTime(booking.getReturnTime())
                .message("Checkout request submitted successfully. Staff will contact you for handover inspection.")
                .build();
    }

    // Tra email đăng nhập -> UUID thật của user.
    // Đặt ở đây (Service layer) vì Service là nơi được phép gọi Repository,
    // Controller không nên biết tới UserRepository.
    private UUID resolveCustomerId(String customerEmail) {
        User user = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        return user.getId();
    }

    private Booking validateActiveBooking(UUID bookingId, UUID customerId) {
        Booking booking = bookingRepository.findByIdAndCustomerId(bookingId, customerId)
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        if (booking.getStatus() != BookingStatus.ACTIVE) {
            throw new AppException(ErrorCode.BOOKING_NOT_CHECKED_IN);
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
                .facilityName(facility != null ? facility.getName() : "Unassigned Facility")
                .facilityAddress(facility != null ? facility.getAddress() : "")
                .unitCode(unit != null ? unit.getUnitCode() : "Unassigned")
                .unitTypeName(unitType != null ? unitType.getTypeName() : "")
                .dimensions(unitType != null ? unitType.getDimensions() : "")
                .areaSqm(unitType != null ? unitType.getAreaSqm() : null)
                .startDate(b.getStartDate())
                .endDate(b.getEndDate())
                .rentalMonths(b.getRentalMonths())
                .status(b.getStatus())
                .totalRentalFee(b.getTotalRentalFee())
                .depositPaid(b.getDepositPaid())
                .activeAccess(b.getStatus() == BookingStatus.ACTIVE)
                .build();
    }
}