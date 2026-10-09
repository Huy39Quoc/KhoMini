package com.storehub.service.impl;

import com.storehub.dto.request.BookingCreationRequest;
import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.BookingResponse;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.FacilityStatus;
import com.storehub.enums.UnitStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.FacilityRepository;
import com.storehub.repository.StorageUnitRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.BookingService;
import com.storehub.service.FacilityPolicyService;
import com.storehub.service.PaymentService;
import com.storehub.service.PricingService;
import com.storehub.service.WaitlistService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookingServiceImpl implements BookingService {

    private static final int BOOKING_EXPIRY_MINUTES = 30;

    private final BookingRepository bookingRepository;
    private final FacilityRepository facilityRepository;
    private final StorageUnitRepository storageUnitRepository;
    private final UserRepository userRepository;
    private final PricingService pricingService;
    private final WaitlistService waitlistService;
    private final FacilityPolicyService facilityPolicyService;
    @org.springframework.context.annotation.Lazy
    private final PaymentService paymentService;

    @Override
    @Transactional
    public BookingResponse createBooking(
            String customerEmail,
            BookingCreationRequest request
    ) {
        User customer = userRepository
                .findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        Facility facility = facilityRepository.findById(request.getFacilityId())
                .orElseThrow(() -> new AppException(ErrorCode.FACILITY_NOT_FOUND));
        if (facility.getStatus() != FacilityStatus.ACTIVE) {
            throw new AppException(ErrorCode.FACILITY_NOT_ACTIVE);
        }

        if (!facilityPolicyService.isMinRentalMonthsSatisfied(
                request.getFacilityId(), request.getRentalMonths())) {
            throw new AppException(ErrorCode.RENTAL_BELOW_MINIMUM_MONTHS);
        }

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
                        .facilityId(request.getFacilityId())
                        .startDate(request.getStartDate())
                        .rentalMonths(request.getRentalMonths())
                        .build();

        RentalQuoteResponse quote =
                pricingService.calculateRentalQuote(quoteRequest);

        selectedUnit.setStatus(UnitStatus.RESERVED);
        storageUnitRepository.save(selectedUnit);

        String bookingCode = "BK-" + UUID.randomUUID()
                .toString().replace("-", "")
                .substring(0, 20).toUpperCase(java.util.Locale.ROOT);

        LocalDateTime expiresAt = LocalDateTime.now().plusMinutes(BOOKING_EXPIRY_MINUTES);

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
                .expiresAt(expiresAt)
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
                .depositAmount(quote.getDepositAmount())
                .totalExtraFees(quote.getTotalExtraFees())
                .initialPaymentAmount(quote.getInitialPaymentAmount())
                .depositPaid(savedBooking.getDepositPaid())
                .status(savedBooking.getStatus())
                .createdAt(savedBooking.getCreatedAt())
                .expiresAt(expiresAt)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public RentalQuoteResponse getRentalQuote(
            RentalQuoteRequest request
    ) {
        return pricingService.calculateRentalQuote(request);
    }

    @Override
    @Transactional
    public void cancelBooking(UUID bookingId, String customerEmail) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        Booking booking = bookingRepository.findByIdAndCustomerId(bookingId, customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        BookingStatus previousStatus = booking.getStatus();
        if (previousStatus != BookingStatus.PENDING_PAYMENT
                && previousStatus != BookingStatus.CONFIRMED) {
            throw new AppException(ErrorCode.BOOKING_CANCEL_NOT_ALLOWED);
        }

        // Đơn đã đặt cọc (CONFIRMED): hoàn cọc theo bậc chính sách huỷ của cơ sở
        BigDecimal refunded = BigDecimal.ZERO;
        if (previousStatus == BookingStatus.CONFIRMED
                && booking.getStorageUnit() != null
                && booking.getStorageUnit().getFacility() != null) {
            refunded = paymentService.refundOnCancellation(booking);
        }

        booking.setStatus(BookingStatus.CANCELLED);
        bookingRepository.save(booking);

        StorageUnit unit = booking.getStorageUnit();
        if (unit != null) {
            unit.setStatus(UnitStatus.AVAILABLE);
            storageUnitRepository.save(unit);

            try {
                UUID facilityId = unit.getFacility() != null ? unit.getFacility().getId() : null;
                UUID unitTypeId = unit.getUnitType() != null ? unit.getUnitType().getId() : null;
                if (facilityId != null && unitTypeId != null) {
                    waitlistService.notifyNextInWaitlist(facilityId, unitTypeId);
                }
            } catch (Exception e) {
                log.warn("Failed to notify waitlist after booking {} cancelled: {}",
                        bookingId, e.getMessage());
            }
        }

        log.info("Booking {} cancelled by customer {} (refunded: {})",
                bookingId, customerEmail, refunded);
    }
}
