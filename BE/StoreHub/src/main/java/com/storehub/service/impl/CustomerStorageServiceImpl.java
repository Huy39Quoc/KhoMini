package com.storehub.service.impl;

import com.storehub.dto.request.CheckoutRequest;
import com.storehub.dto.request.ExtendRentalRequest;
import com.storehub.dto.request.ResetPinRequest;
import com.storehub.dto.request.SetupPinRequest;
import com.storehub.dto.request.UnlockRequest;
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
import org.springframework.security.crypto.password.PasswordEncoder;
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
    private final PasswordEncoder passwordEncoder;

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

    // ===================== SMART ACCESS (mở/đóng khóa bằng PIN) =====================
    // Quy ước:
    //  - PIN 6 số do HỆ THỐNG CẤP hoặc KHÁCH TỰ ĐẶT; server chỉ lưu bản băm BCrypt.
    //  - Mở khóa bắt buộc nhập đúng PIN. Đóng khóa không cần PIN (luôn an toàn).
    //  - Sai PIN 5 lần -> khóa tạm 15 phút. Quên PIN -> đặt lại bằng mật khẩu tài khoản.
    //  - Mỗi lần đổi/đặt lại PIN, cửa tự về trạng thái đã khóa.

    private static final int MAX_PIN_ATTEMPTS = 5;
    private static final int PIN_LOCKOUT_MINUTES = 15;

    @Override
    @Transactional
    public SmartAccessResponse getSmartAccessInfo(UUID bookingId, String customerEmail) {
        Booking booking = validateActiveBooking(bookingId, resolveCustomerId(customerEmail));
        reconcileOverdueState(booking);
        requireAccessEnabled(booking);
        return buildAccessResponse(booking, null);
    }

    @Override
    @Transactional
    public SmartAccessResponse setupPin(UUID bookingId, String customerEmail, SetupPinRequest request) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);
        requireAccessEnabled(booking);

        if (hasPin(booking)) {
            throw new AppException(ErrorCode.PIN_ALREADY_SET);
        }

        String plainPin = request.getNewPin();
        boolean generated = plainPin == null || plainPin.isBlank();
        if (generated) {
            plainPin = generateRandomPin();
        }
        storeNewPin(booking, plainPin);
        bookingRepository.save(booking);

        activityLogService.record(customerId, ActivityAction.ACCESS_CREDENTIAL_ISSUE, "BOOKING", booking.getId(),
                (generated ? "System issued" : "Customer set") + " access PIN for booking " + booking.getBookingCode(),
                null, null);

        return buildAccessResponse(booking, generated ? plainPin : null);
    }

    // noRollbackFor: bộ đếm nhập sai phải được lưu dù request này kết thúc bằng lỗi.
    @Override
    @Transactional(noRollbackFor = AppException.class)
    public SmartAccessResponse updateAccessPin(UUID bookingId, String customerEmail, UpdatePinRequest request) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);
        requireAccessEnabled(booking);

        verifyPinOrCount(booking, request.getCurrentPin());

        storeNewPin(booking, request.getNewPin());
        bookingRepository.save(booking);

        activityLogService.record(customerId, ActivityAction.ACCESS_CREDENTIAL_UPDATE, "BOOKING", booking.getId(),
                "Changed access PIN for booking " + booking.getBookingCode(), null, null);

        return buildAccessResponse(booking, null);
    }

    @Override
    @Transactional
    public SmartAccessResponse resetPin(UUID bookingId, String customerEmail, ResetPinRequest request) {
        User user = userRepository.findByEmail(customerEmail)
                .orElseThrow(() -> new AppException(ErrorCode.USER_NOT_FOUND));
        Booking booking = validateActiveBooking(bookingId, user.getId());
        requireAccessEnabled(booking);

        if (request.getPassword() == null
                || !passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new AppException(ErrorCode.PIN_RESET_PASSWORD_INCORRECT);
        }

        String plainPin = request.getNewPin();
        boolean generated = plainPin == null || plainPin.isBlank();
        if (generated) {
            plainPin = generateRandomPin();
        }
        storeNewPin(booking, plainPin);
        bookingRepository.save(booking);

        activityLogService.record(user.getId(), ActivityAction.ACCESS_CREDENTIAL_UPDATE, "BOOKING", booking.getId(),
                "Reset forgotten access PIN for booking " + booking.getBookingCode()
                        + (generated ? " (system generated)" : " (customer chosen)"),
                null, null);

        return buildAccessResponse(booking, generated ? plainPin : null);
    }

    @Override
    @Transactional(noRollbackFor = AppException.class)
    public SmartAccessResponse unlockWithPin(UUID bookingId, String customerEmail, UnlockRequest request) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);
        requireAccessEnabled(booking);

        verifyPinOrCount(booking, request.getPin());

        booking.setUnitLocked(false);
        bookingRepository.save(booking);

        activityLogService.record(customerId, ActivityAction.UNIT_UNLOCKED, "BOOKING", booking.getId(),
                "Unlocked storage unit with PIN for booking " + booking.getBookingCode(), null, null);

        return buildAccessResponse(booking, null);
    }

    // Đóng khóa: không cần PIN.
    @Override
    @Transactional
    public SmartAccessResponse setLockState(UUID bookingId, String customerEmail, boolean locked) {
        UUID customerId = resolveCustomerId(customerEmail);
        Booking booking = validateActiveBooking(bookingId, customerId);
        requireAccessEnabled(booking);

        if (!locked) {
            // Mở khóa bắt buộc đi qua unlockWithPin.
            throw new AppException(ErrorCode.INVALID_REQUEST);
        }
        booking.setUnitLocked(true);
        bookingRepository.save(booking);

        activityLogService.record(customerId, ActivityAction.UNIT_LOCKED,
                "BOOKING", booking.getId(),
                "Locked storage unit for booking " + booking.getBookingCode(),
                null, null);

        return buildAccessResponse(booking, null);
    }

    private boolean hasPin(Booking booking) {
        return booking.getAccessPin() != null && !booking.getAccessPin().isBlank();
    }

    // Lưu PIN mới (băm), xóa bộ đếm sai, và đóng cửa lại cho an toàn.
    private void storeNewPin(Booking booking, String plainPin) {
        booking.setAccessPin(passwordEncoder.encode(plainPin));
        booking.setPinUpdatedAt(LocalDateTime.now());
        booking.setPinFailedAttempts(0);
        booking.setPinLockedUntil(null);
        booking.setUnitLocked(true);
    }

    // Kiểm tra PIN: đang bị khóa tạm -> từ chối; sai -> tăng bộ đếm (đủ 5 lần thì khóa 15 phút).
    private void verifyPinOrCount(Booking booking, String plainPin) {
        if (!hasPin(booking)) {
            throw new AppException(ErrorCode.PIN_NOT_SET);
        }
        LocalDateTime now = LocalDateTime.now();
        if (booking.getPinLockedUntil() != null && now.isBefore(booking.getPinLockedUntil())) {
            throw new AppException(ErrorCode.PIN_TEMPORARILY_LOCKED);
        }
        if (plainPin != null && passwordEncoder.matches(plainPin, booking.getAccessPin())) {
            booking.setPinFailedAttempts(0);
            booking.setPinLockedUntil(null);
            return;
        }

        int failed = (booking.getPinFailedAttempts() == null ? 0 : booking.getPinFailedAttempts()) + 1;
        if (failed >= MAX_PIN_ATTEMPTS) {
            booking.setPinFailedAttempts(0);
            booking.setPinLockedUntil(now.plusMinutes(PIN_LOCKOUT_MINUTES));
        } else {
            booking.setPinFailedAttempts(failed);
        }
        bookingRepository.save(booking);
        throw new AppException(failed >= MAX_PIN_ATTEMPTS
                ? ErrorCode.PIN_TEMPORARILY_LOCKED
                : ErrorCode.PIN_INCORRECT);
    }

    private SmartAccessResponse buildAccessResponse(Booking booking, String generatedPin) {
        SmartAccessResponse response = customerStorageMapper.toSmartAccessResponse(booking);
        int failed = booking.getPinFailedAttempts() == null ? 0 : booking.getPinFailedAttempts();
        response.setAttemptsRemaining(Math.max(0, MAX_PIN_ATTEMPTS - failed));
        response.setGeneratedPin(generatedPin);
        return response;
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

        booking.setScheduledReturnTime(request.getScheduledReturnTime());
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
                .scheduledReturnTime(booking.getScheduledReturnTime())
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
    // hợp đồng hết quá hạn: gỡ cờ quá hạn và mở lại truy cập (PIN được cấp/đặt lại ở lần
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

    // Kho đã bị thu hồi mã truy cập do quá hạn thì không được xem/đổi PIN hay khóa/mở.
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
