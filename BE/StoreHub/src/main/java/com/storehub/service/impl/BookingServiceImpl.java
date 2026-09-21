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

@Service
@RequiredArgsConstructor
public class BookingServiceImpl
        implements BookingService {

    private final BookingRepository bookingRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final UserRepository userRepository;
    private final PricingService pricingService;

    @Override
    @Transactional
    public BookingResponse createBooking(
            String customerEmail,
            BookingCreationRequest request
    ) {
        User customer = userRepository
                .findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(
                        ErrorCode.USER_NOT_FOUND
                ));

        /*
         * Khóa một unit AVAILABLE trong transaction.
         * FOR UPDATE SKIP LOCKED giúp tránh hai booking
         * cùng lấy một storage unit.
         */
        StorageUnit selectedUnit = storageUnitRepository
                .claimAvailableUnitId(
                        request.getFacilityId(),
                        request.getUnitTypeId()
                )
                .flatMap(storageUnitRepository::findById)
                .orElseThrow(() -> new AppException(
                        ErrorCode.NO_AVAILABLE_UNIT
                ));

        RentalQuoteRequest quoteRequest =
                RentalQuoteRequest.builder()
                        .unitTypeId(request.getUnitTypeId())
                        .startDate(request.getStartDate())
                        .rentalMonths(request.getRentalMonths())
                        .build();

        RentalQuoteResponse quote =
                pricingService.calculateRentalQuote(
                        quoteRequest
                );

        /*
         * Sau khi giữ chỗ, unit ở trạng thái RESERVED.
         * Chỉ sau khi thanh toán cọc mới chuyển booking sang CONFIRMED.
         * Chỉ khi staff check-in mới chuyển unit sang OCCUPIED.
         */
        selectedUnit.setStatus(UnitStatus.RESERVED);
        storageUnitRepository.save(selectedUnit);

        String bookingCode =
                "BK-" + System.currentTimeMillis();

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

        Booking savedBooking =
                bookingRepository.save(booking);

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
    public RentalQuoteResponse getRentalQuote(
            RentalQuoteRequest request
    ) {
        return pricingService.calculateRentalQuote(request);
    }
}