package com.storehub.service.impl;

import com.storehub.dto.request.BookingCreationRequest;
import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.BookingResponse;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.BookingService;
import com.storehub.service.PricingService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

@Service
@RequiredArgsConstructor
public class BookingServiceImpl implements BookingService {

    private final BookingRepository bookingRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final UserRepository userRepository;
    private final PricingService pricingService;

    @Override
    @Transactional
    public BookingResponse createBooking(String customerEmail, BookingCreationRequest request) {
        // 1. Xác định khách hàng từ email JWT
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        // 2. Tìm kho khả dụng – derived query type-safe với Enum
        List<StorageUnit> availableUnits = storageUnitRepository.findByFacility_IdAndUnitType_IdAndStatus(
                request.getFacilityId(),
                request.getUnitTypeId(),
                UnitStatus.AVAILABLE
        );
        if (availableUnits.isEmpty()) {
            throw new AppException(ErrorCode.NO_AVAILABLE_UNIT);
        }
        StorageUnit selectedUnit = availableUnits.get(0);

        // 3. Tính báo giá
        RentalQuoteRequest quoteRequest = RentalQuoteRequest.builder()
                .unitTypeId(request.getUnitTypeId())
                .startDate(request.getStartDate())
                .rentalMonths(request.getRentalMonths())
                .build();
        RentalQuoteResponse quote = pricingService.calculateRentalQuote(quoteRequest);

        // 4. Đặt trạng thái kho là RESERVED (gán Enum trực tiếp, không dùng .name())
        selectedUnit.setStatus(UnitStatus.RESERVED);
        storageUnitRepository.save(selectedUnit);

        // 5. Tạo booking
        String bookingCode = "BK-" + System.currentTimeMillis();
        Booking booking = Booking.builder()
                .bookingCode(bookingCode)
                .customer(customer)
                .storageUnit(selectedUnit)
                .startDate(request.getStartDate())
                .endDate(quote.getEndDate())
                .rentalMonths(request.getRentalMonths())
                .totalRentalFee(quote.getTotalRentalFee())
                .depositPaid(BigDecimal.ZERO)
                .status(BookingStatus.PENDING_PAYMENT)
                .build();

        Booking savedBooking = bookingRepository.save(booking);

        return BookingResponse.builder()
                .id(savedBooking.getId())
                .bookingCode(savedBooking.getBookingCode())
                .customerId(customer.getId())
                .storageUnitId(selectedUnit.getId())
                .unitCode(selectedUnit.getUnitCode())
                .startDate(savedBooking.getStartDate())
                .endDate(savedBooking.getEndDate())
                .rentalMonths(savedBooking.getRentalMonths())
                .totalRentalFee(savedBooking.getTotalRentalFee())
                .depositPaid(savedBooking.getDepositPaid())
                .status(savedBooking.getStatus())
                .createdAt(savedBooking.getCreatedAt())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public RentalQuoteResponse getRentalQuote(RentalQuoteRequest request) {
        return pricingService.calculateRentalQuote(request);
    }
}
