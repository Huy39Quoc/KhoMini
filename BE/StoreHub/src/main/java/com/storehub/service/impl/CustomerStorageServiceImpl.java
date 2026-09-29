package com.storehub.service.impl;

import com.storehub.dto.request.CheckoutRequest;
import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.dto.request.UpdatePinRequest;
import com.storehub.dto.response.ContractOperationResponse;
import com.storehub.dto.response.MyUnitResponse;
import com.storehub.dto.response.SmartAccessResponse;
import com.storehub.entity.Booking;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.dto.request.PaymentInitiationRequest;
import com.storehub.dto.response.PaymentResponse;
import com.storehub.entity.Payment;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.repository.PaymentRepository;
import java.time.temporal.ChronoUnit;
import static com.storehub.common.PaymentNotes.OVERDUE_LATE_FEE;
import static com.storehub.common.PaymentNotes.RENTAL_EXTENSION;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.UserRepository;
import com.storehub.enums.ActivityAction;
import com.storehub.mapper.CustomerStorageMapper;
import com.storehub.service.ActivityLogService;
import com.storehub.service.CustomerStorageService;
import com.storehub.service.FacilityPolicyService;
import com.storehub.service.PaymentService;
import com.storehub.service.PricingService;
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
    private final PaymentRepository paymentRepository;
    private final ActivityLogService activityLogService;

    private final PricingService pricingService;
    private final FacilityPolicyService facilityPolicyService;
    private final PaymentService paymentService;
    private final CustomerStorageMapper customerStorageMapper;

    @Override
    @Transactional
    public List<MyUnitResponse> getMyRentedUnits(String customerEmail) {
        UUID customerId = resolveCustomerId(customerEmail);

        List<BookingStatus> activeStatuses = Arrays.asList(
                BookingStatus.CONFIRMED,
                BookingStatus.ACTIVE
        );

        List<Booking> bookings = bookingRepository.findActiveBookingsByCustomerId(customerId, activeStatuses);
        bookings.forEach(this::reconcileOverdueState);
        return bookings.stream().map(this::mapToResponse).collect(Collectors.toList());
    }

    @Override
    @Transactional
    public SmartAccessResponse getSmartAccessInfo(UUID bookingId, String customerEmail) {
        Booking booking = validateActiveBooking(bookingId, resolveCustomerId(customerEmail));
        reconcileOverdueState(booking);
        requireAccessEnabled(booking);

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

        return customerStorageMapper.toSmartAccessResponse(booking);
    }

    @Override
    @Transactional
    public SmartAccessResponse updateAccessPin(UUID bookingId, String customerEmail, UpdatePinRequest request) {
        Booking booking = validateActiveBooking(bookingId, resolveCustomerId(customerEmail));
        requireAccessEnabled(booking);

        booking.setAccessPin(request.getNewPin());
        booking.setPinUpdatedAt(LocalDateTime.now());
        bookingRepository.save(booking);

        UUID customerId = resolveCustomerId(customerEmail);
        activityLogService.record(customerId, ActivityAction.ACCESS_CREDENTIAL_UPDATE, "BOOKING", booking.getId(),
                "Updated access PIN for booking " + booking.getBookingCode(), null, null);

        return customerStorageMapper.toSmartAccessResponse(booking);
    }

    @Override
    @Transactional
    public SmartAccessResponse setLockState(UUID bookingId, String customerEmail, boolean locked) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);
        requireAccessEnabled(booking);

        booking.setUnitLocked(locked);
        bookingRepository.save(booking);

        activityLogService.record(customerId, locked ? ActivityAction.UNIT_LOCKED : ActivityAction.UNIT_UNLOCKED,
                "BOOKING", booking.getId(),
                (locked ? "Locked" : "Unlocked") + " storage unit for booking " + booking.getBookingCode(),
                null, null);

        return customerStorageMapper.toSmartAccessResponse(booking);
    }

    @Override
    @Transactional
    public ContractOperationResponse extendRental(UUID bookingId, String customerEmail, ExtendRentalRequest request) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);

        if (booking.getPendingExtraMonths() != null) {
            throw new AppException(ErrorCode.EXTENSION_ALREADY_PENDING);
        }

        if (findPendingLateFee(booking.getId()) != null) {
            throw new AppException(ErrorCode.OVERDUE_FEE_UNPAID);
        }

        if (booking.getStorageUnit() == null || booking.getStorageUnit().getFacility() == null) {
            throw new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND);
        }
        UUID facilityId = booking.getStorageUnit().getFacility().getId();

        if (!facilityPolicyService.isWithinRenewalWindow(facilityId, booking.getEndDate())) {
            throw new AppException(ErrorCode.RENEWAL_WINDOW_NOT_REACHED);
        }

        LocalDate oldEndDate = booking.getEndDate();
        int extraMonths = request.getExtraMonths();
        LocalDate projectedNewEndDate = oldEndDate.plusMonths(extraMonths);

        BigDecimal additionalFee = pricingService.calculateExtensionFee(booking.getStorageUnit(), extraMonths);

        booking.setPendingExtraMonths(extraMonths);
        booking.setPendingExtensionFee(additionalFee);
        bookingRepository.save(booking);

        activityLogService.record(customerId, ActivityAction.RENEWAL_REQUEST, "BOOKING", booking.getId(),
                "Requested extension for booking " + booking.getBookingCode() + " by " + extraMonths
                        + " month(s), fee " + additionalFee + " awaiting payment",
                oldEndDate, projectedNewEndDate);

        PaymentInitiationRequest paymentRequest = new PaymentInitiationRequest();
        paymentRequest.setBookingId(booking.getId());
        paymentRequest.setPaymentType(PaymentType.EXTRA_CHARGE);
        paymentRequest.setPaymentMethod(request.getPaymentMethod());
        PaymentResponse payment = paymentService.initiatePayment(customerEmail, paymentRequest);

        return ContractOperationResponse.builder()
                .bookingId(booking.getId())
                .bookingCode(booking.getBookingCode())
                .status(booking.getStatus())
                .oldEndDate(oldEndDate)
                .newEndDate(projectedNewEndDate)
                .totalRentalMonths(booking.getRentalMonths() + extraMonths)
                .additionalFee(additionalFee)
                .updatedTotalFee(booking.getTotalRentalFee().add(additionalFee))
                .paymentRequired(true)
                .transactionId(payment.getTransactionId())
                .qrCodeUrl(payment.getQrCodeUrl())
                .message("Extension fee calculated. Please complete payment (transactionId: "
                        + payment.getTransactionId() + ") to activate the " + extraMonths + " month extension.")
                .build();
    }

    @Override
    @Transactional
    public ContractOperationResponse requestCheckout(UUID bookingId, String customerEmail, CheckoutRequest request) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);

        if (booking.getStorageUnit() == null || booking.getStorageUnit().getFacility() == null) {
            throw new AppException(ErrorCode.STORAGE_UNIT_NOT_FOUND);
        }
        UUID facilityId = booking.getStorageUnit().getFacility().getId();

        if (!facilityPolicyService.isReturnNoticeSatisfied(facilityId, request.getScheduledReturnTime())) {
            throw new AppException(ErrorCode.RETURN_NOTICE_NOT_SATISFIED);
        }

        booking.setReturnTime(request.getScheduledReturnTime());
        bookingRepository.save(booking);

        activityLogService.record(customerId, ActivityAction.CHECKOUT_REQUEST, "BOOKING", booking.getId(),
                "Requested checkout for booking " + booking.getBookingCode() + " at " + request.getScheduledReturnTime()
                        + (request.getNotes() != null && !request.getNotes().isBlank()
                        ? " (notes: " + request.getNotes().trim() + ")" : ""),
                null, request.getScheduledReturnTime());

        return ContractOperationResponse.builder()
                .bookingId(booking.getId())
                .bookingCode(booking.getBookingCode())
                .status(booking.getStatus())
                .scheduledReturnTime(booking.getReturnTime())
                .message("Checkout request submitted successfully. Staff will contact you for handover inspection.")
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public PaymentResponse getPendingExtensionPayment(UUID bookingId, String customerEmail) {
        return paymentService.getPendingExtensionPayment(customerEmail, bookingId);
    }

    @Override
    @Transactional
    public ContractOperationResponse cancelPendingExtension(UUID bookingId, String customerEmail) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);

        if (booking.getPendingExtraMonths() == null) {
            throw new AppException(ErrorCode.NO_PENDING_EXTENSION);
        }

        int cancelledMonths = booking.getPendingExtraMonths();

        // Đóng giao dịch gia hạn đang treo để không còn thanh toán được QR cũ
        paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                        booking.getId(), PaymentType.EXTRA_CHARGE, PaymentStatus.PENDING, RENTAL_EXTENSION)
                .ifPresent(payment -> {
                    payment.setStatus(PaymentStatus.FAILED);
                    paymentRepository.save(payment);
                });

        booking.setPendingExtraMonths(null);
        booking.setPendingExtensionFee(null);
        bookingRepository.save(booking);

        activityLogService.record(customerId, ActivityAction.RENEWAL_REQUEST, "BOOKING", booking.getId(),
                "Cancelled pending " + cancelledMonths + "-month extension request for booking "
                        + booking.getBookingCode(),
                null, null);

        return ContractOperationResponse.builder()
                .bookingId(booking.getId())
                .bookingCode(booking.getBookingCode())
                .status(booking.getStatus())
                .oldEndDate(booking.getEndDate())
                .totalRentalMonths(booking.getRentalMonths())
                .updatedTotalFee(booking.getTotalRentalFee())
                .paymentRequired(false)
                .message("Extension request cancelled. You can submit a new one at any time.")
                .build();
    }

    // Sau khi gia hạn (do PaymentService xác nhận) mà ngày hết hạn mới đã ở tương lai thì
    // hợp đồng hết quá hạn: gỡ cờ quá hạn và mở lại truy cập (PIN/QR được cấp lại ở lần
    // xem Smart Key kế tiếp). Đặt ở đây để không phải sửa luồng thanh toán của Flow 1.
    private void reconcileOverdueState(Booking booking) {
        if (booking.getOverdueDetectedAt() == null
                || booking.getEndDate() == null
                || booking.getEndDate().isBefore(LocalDate.now())) {
            return;
        }

        boolean accessWasDisabled = booking.getAccessDisabledAt() != null;
        booking.setOverdueDetectedAt(null);
        booking.setOverdueFeeAccrued(BigDecimal.ZERO);
        booking.setSealingPendingAt(null);
        booking.setAccessDisabledAt(null);
        bookingRepository.save(booking);

        if (accessWasDisabled) {
            activityLogService.record(booking.getCustomer().getId(),
                    ActivityAction.ACCESS_CREDENTIAL_ISSUE, "BOOKING", booking.getId(),
                    "Access restored for booking " + booking.getBookingCode()
                            + " after the overdue rental was extended",
                    null, null);
        }
    }

    // Kho đã bị thu hồi mã truy cập do quá hạn thì không được xem/đổi PIN, QR hay khóa/mở.
    private void requireAccessEnabled(Booking booking) {
        if (booking.getAccessDisabledAt() != null) {
            throw new AppException(ErrorCode.ACCESS_DISABLED_OVERDUE);
        }
    }

    // Khoản phí trễ hạn đang chờ thanh toán (scheduler tạo), null nếu không có.
    private Payment findPendingLateFee(UUID bookingId) {
        return paymentRepository
                .findFirstByBooking_IdAndPaymentTypeAndStatusAndNoteOrderByPaymentTimeDesc(
                        bookingId, PaymentType.EXTRA_CHARGE, PaymentStatus.PENDING, OVERDUE_LATE_FEE)
                .filter(p -> p.getAmount() != null && p.getAmount().signum() > 0)
                .orElse(null);
    }

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
        MyUnitResponse response = customerStorageMapper.toMyUnitResponse(b);

        if (b.getStatus() == BookingStatus.ACTIVE && b.getEndDate() != null
                && b.getEndDate().isBefore(LocalDate.now())) {
            response.setOverdueDays(ChronoUnit.DAYS.between(b.getEndDate(), LocalDate.now()));
        }

        Payment lateFee = b.getOverdueDetectedAt() != null ? findPendingLateFee(b.getId()) : null;
        response.setOverdueFeeOutstanding(lateFee != null ? lateFee.getAmount() : BigDecimal.ZERO);
        return response;
    }
}