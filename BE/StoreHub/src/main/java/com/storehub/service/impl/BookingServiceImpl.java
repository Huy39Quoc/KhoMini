package com.storehub.service.impl;

import com.storehub.dto.request.BookingCreationRequest;
import com.storehub.dto.request.RentalQuoteRequest;
import com.storehub.dto.response.BookingResponse;
import com.storehub.dto.response.FacilityPolicyResponse;
import com.storehub.dto.response.RentalQuoteResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.Payment;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.enums.FacilityStatus;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.enums.UnitStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
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
import java.time.LocalTime;
import java.util.UUID;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookingServiceImpl implements BookingService {

    private static final int BOOKING_EXPIRY_MINUTES = 30;

    private final BookingRepository bookingRepository;
    private final PaymentRepository paymentRepository;
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

        LocalTime checkInTime = request.getCheckInTime() != null
                ? request.getCheckInTime() : facility.getOpenTime();
        if (checkInTime == null || facility.getOpenTime() == null
                || facility.getCloseTime() == null
                || checkInTime.isBefore(facility.getOpenTime())
                || !checkInTime.isBefore(facility.getCloseTime())) {
            throw new AppException(ErrorCode.CHECKIN_TIME_OUTSIDE_OPEN_HOURS);
        }
        if (!request.getStartDate().atTime(checkInTime).isAfter(LocalDateTime.now())) {
            throw new AppException(ErrorCode.CHECKIN_TIME_IN_PAST);
        }

        if (!facilityPolicyService.isMinRentalMonthsSatisfied(
                request.getFacilityId(), request.getRentalMonths())) {
            throw new AppException(ErrorCode.RENTAL_BELOW_MINIMUM_MONTHS);
        }

        if (!facilityPolicyService.isAdvanceReservationAllowed(
                request.getFacilityId(), request.getStartDate())) {
            throw new AppException(ErrorCode.ADVANCE_RESERVATION_EXCEEDED);
        }

        if (!Boolean.TRUE.equals(request.getProhibitedItemsConfirmed())
                || !Boolean.TRUE.equals(request.getTermsConfirmed())) {
            throw new AppException(ErrorCode.TERMS_AND_CONDITIONS_REQUIRED);
        }

        FacilityPolicyResponse cancellationPolicy = facilityPolicyService.getForBooking(request.getFacilityId());
        if (cancellationPolicy == null || cancellationPolicy.getTermsHash() == null) {
            throw new AppException(ErrorCode.TERMS_NOT_AVAILABLE);
        }
        if (!cancellationPolicy.getTermsVersion().equals(request.getTermsVersion())
                || !cancellationPolicy.getTermsHash().equals(request.getTermsHash())) {
            throw new AppException(ErrorCode.TERMS_CHANGED);
        }
        LocalDateTime policyCapturedAt = LocalDateTime.now();
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
                .overdueDailyLateFee(cancellationPolicy.getDailyLateFee())
                .overdueGraceDays(cancellationPolicy.getOverdueGraceDays())
                .overdueAccessDisableDays(cancellationPolicy.getOverdueAccessDisableDays())
                .overdueSealingDays(cancellationPolicy.getOverdueSealingDays())
                .overduePolicyCapturedAt(policyCapturedAt)
                .overduePolicyLegacy(false)
                .cancellationFullRefundHours(cancellationPolicy.getCancellationFullRefundHours())
                .cancellationPartialRefundHours(cancellationPolicy.getCancellationPartialRefundHours())
                .cancellationPartialRefundPercent(cancellationPolicy.getCancellationPartialRefundPercent())
                .cancellationPolicyEffectiveAt(cancellationPolicy != null && cancellationPolicy.getCancellationPolicyEffectiveAt() != null
                        ? cancellationPolicy.getCancellationPolicyEffectiveAt() : policyCapturedAt)
                .cancellationPolicyCapturedAt(policyCapturedAt)
                .cancellationPolicyLegacy(false)
                .bookingCode(bookingCode)
                .customer(customer)
                .storageUnit(selectedUnit)
                .unitAssignmentConfirmed(false)
                .startDate(request.getStartDate())
                .scheduledCheckInTime(request.getStartDate().atTime(checkInTime))
                .endDate(quote.getEndDate())
                .rentalMonths(request.getRentalMonths())
                .totalRentalFee(quote.getTotalRentalFee())
                .quotedDepositAmount(quote.getDepositAmount())
                .quotedManagementFee(quote.getTotalExtraFees())
                .depositPaid(BigDecimal.ZERO)
                .status(BookingStatus.PENDING_PAYMENT)
                .expiresAt(expiresAt)
                .prohibitedItemsAccepted(true)
                .termsAccepted(true)
                .termsAcceptedAt(LocalDateTime.now())
                .termsVersion(cancellationPolicy.getTermsVersion())
                .termsContentSnapshot(cancellationPolicy.getTermsAndConditions())
                .prohibitedItemsSnapshot(cancellationPolicy.getProhibitedItems())
                .termsHash(cancellationPolicy.getTermsHash())
                .build();

        Booking savedBooking = bookingRepository.save(booking);

        return BookingResponse.builder()
                .id(savedBooking.getId())
                .bookingCode(savedBooking.getBookingCode())
                .customerId(customer.getId())
                .storageUnitId(selectedUnit.getId())
                .unitCode(selectedUnit.getUnitCode())
                .unitAssignmentConfirmed(false)
                .facilityName(facility.getName())
                .unitTypeName(selectedUnit.getUnitType().getTypeName())
                .unitTypeDimensions(selectedUnit.getUnitType().getDimensions())
                .startDate(savedBooking.getStartDate())
                .scheduledCheckInTime(savedBooking.getScheduledCheckInTime())
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
                .prohibitedItemsAccepted(savedBooking.getProhibitedItemsAccepted())
                .termsAccepted(savedBooking.getTermsAccepted())
                .termsAcceptedAt(savedBooking.getTermsAcceptedAt())
                .termsVersion(savedBooking.getTermsVersion())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public List<BookingResponse> getPayableBookings(String customerEmail) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        return bookingRepository.findPayableBookingsByCustomerId(
                        customer.getId(), BookingStatus.PENDING_PAYMENT, LocalDateTime.now())
                .stream().map(booking -> {
                    StorageUnit unit = booking.getStorageUnit();
                    Facility facility = unit.getFacility();
                    BigDecimal deposit = booking.getQuotedDepositAmount() != null
                            ? booking.getQuotedDepositAmount()
                            : pricingService.calculateDepositAmount(
                                    facility.getId(), booking.getTotalRentalFee(),
                                    unit.getUnitType().getDepositAmount());
                    BigDecimal fees = booking.getQuotedManagementFee() != null
                            ? booking.getQuotedManagementFee()
                            : pricingService.calculateManagementFee(
                                    facility.getId(), booking.getRentalMonths());
                    // Existing VNPay attempts retain their original amounts even if policy changes.
                    List<Payment> pending = paymentRepository.findByBooking_IdAndStatusAndPaymentTypeIn(
                            booking.getId(), PaymentStatus.PENDING,
                            List.of(PaymentType.DEPOSIT, PaymentType.RENTAL_FEE));
                    if (pending.size() == 2) {
                        Payment primary = pending.stream()
                                .filter(p -> p.getPaymentType() == PaymentType.DEPOSIT)
                                .findFirst().orElse(null);
                        if (primary != null && primary.getGatewayAmount() != null) {
                            deposit = primary.getAmount();
                            fees = primary.getGatewayAmount()
                                    .subtract(deposit).subtract(booking.getTotalRentalFee());
                        }
                    }
                    return BookingResponse.builder()
                            .id(booking.getId())
                            .bookingCode(booking.getBookingCode())
                            .customerId(customer.getId())
                            .storageUnitId(unit.getId())
                            .unitCode(unit.getUnitCode())
                            .unitAssignmentConfirmed(Boolean.TRUE.equals(booking.getUnitAssignmentConfirmed()))
                            .facilityName(facility.getName())
                            .unitTypeName(unit.getUnitType().getTypeName())
                            .unitTypeDimensions(unit.getUnitType().getDimensions())
                            .startDate(booking.getStartDate())
                            .scheduledCheckInTime(booking.getScheduledCheckInTime())
                            .endDate(booking.getEndDate())
                            .rentalMonths(booking.getRentalMonths())
                            .totalRentalFee(booking.getTotalRentalFee())
                            .depositAmount(deposit)
                            .totalExtraFees(fees)
                            .initialPaymentAmount(deposit.add(booking.getTotalRentalFee()).add(fees))
                            .depositPaid(booking.getDepositPaid())
                            .status(booking.getStatus())
                            .createdAt(booking.getCreatedAt())
                            .expiresAt(booking.getExpiresAt())
                            .prohibitedItemsAccepted(booking.getProhibitedItemsAccepted())
                            .termsAccepted(booking.getTermsAccepted())
                            .termsAcceptedAt(booking.getTermsAcceptedAt())
                            .termsVersion(booking.getTermsVersion())
                            .build();
                }).toList();
    }

    @Override
    @Transactional
    public void cancelBooking(UUID bookingId, String customerEmail) {
        User customer = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));

        Booking booking = bookingRepository.lockByIdAndCustomerId(bookingId, customer.getId())
                .orElseThrow(() -> new AppException(ErrorCode.BOOKING_NOT_FOUND));

        BookingStatus previousStatus = booking.getStatus();
        if (previousStatus != BookingStatus.PENDING_PAYMENT
                && previousStatus != BookingStatus.CONFIRMED) {
            throw new AppException(ErrorCode.BOOKING_CANCEL_NOT_ALLOWED);
        }

        // Đơn đã đặt cọc (CONFIRMED): hoàn cọc theo bậc chính sách huỷ của cơ sở
        BigDecimal requestedRefund = BigDecimal.ZERO;
        if (previousStatus == BookingStatus.CONFIRMED
                && booking.getStorageUnit() != null
                && booking.getStorageUnit().getFacility() != null) {
            requestedRefund = paymentService.refundOnCancellation(booking);
        }

        booking.setStatus(BookingStatus.CANCELLED);
        if (booking.getHandoverIssueReportedAt() != null) {
            booking.setHandoverIssueStatus(com.storehub.enums.HandoverIssueStatus.CANCELLED);
        }
        bookingRepository.save(booking);

        StorageUnit unit = booking.getStorageUnit();
        // Ngăn đang cần kiểm tra/bảo trì thì giữ nguyên trạng thái, chỉ ngăn đang giữ chỗ mới trả về trống.
        if (unit != null && unit.getStatus() == UnitStatus.RESERVED) {
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

        log.info("Booking {} cancelled by customer {} (refund requested: {})",
                bookingId, customerEmail, requestedRefund);
    }
}
