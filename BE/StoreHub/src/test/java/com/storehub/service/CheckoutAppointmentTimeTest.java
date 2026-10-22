package com.storehub.service;

import com.storehub.dto.request.CheckoutRequest;
import com.storehub.dto.response.ContractOperationResponse;
import com.storehub.entity.*;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.CustomerStorageServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CheckoutAppointmentTimeTest {

    @Mock BookingRepository bookingRepository;
    @Mock UserRepository userRepository;
    @Mock FacilityPolicyService facilityPolicyService;
    @Mock ActivityLogService activityLogService;
    @InjectMocks CustomerStorageServiceImpl service;

    @Test
    void rejectsCheckoutOutsideFacilityHours() {
        UUID bookingId = UUID.randomUUID();
        UUID customerId = UUID.randomUUID();
        String customerEmail = "customer@test.com";

        Facility facility = Facility.builder()
                .openTime(LocalTime.of(8, 0))
                .closeTime(LocalTime.of(20, 0))
                .build();
        facility.setId(UUID.randomUUID());

        StorageUnit unit = StorageUnit.builder()
                .facility(facility)
                .build();

        Booking booking = Booking.builder()
                .status(BookingStatus.ACTIVE)
                .storageUnit(unit)
                .build();

        User user = new User();
        user.setId(customerId);

        when(userRepository.findByEmail(customerEmail)).thenReturn(Optional.of(user));
        when(bookingRepository.lockByIdAndCustomerId(bookingId, customerId)).thenReturn(Optional.of(booking));

        CheckoutRequest request = new CheckoutRequest();
        // 20:39 is outside 08:00 - 20:00
        request.setScheduledReturnTime(LocalDateTime.now().plusDays(1).withHour(20).withMinute(39));

        AppException ex = assertThrows(AppException.class,
                () -> service.requestCheckout(bookingId, customerEmail, request));

        assertEquals(ErrorCode.CHECKOUT_TIME_OUTSIDE_OPEN_HOURS, ex.getErrorCode());
        assertEquals("Giờ hẹn trả kho phải nằm trong khung giờ mở cửa của cơ sở", ex.getErrorCode().getMessage());
    }

    @Test
    void acceptsCheckoutWithinFacilityHours() {
        UUID bookingId = UUID.randomUUID();
        UUID customerId = UUID.randomUUID();
        String customerEmail = "customer@test.com";

        Facility facility = Facility.builder()
                .openTime(LocalTime.of(8, 0))
                .closeTime(LocalTime.of(20, 0))
                .build();
        facility.setId(UUID.randomUUID());

        StorageUnit unit = StorageUnit.builder()
                .facility(facility)
                .build();

        Booking booking = Booking.builder()
                .bookingCode("BK-101")
                .status(BookingStatus.ACTIVE)
                .storageUnit(unit)
                .build();
        booking.setId(bookingId);

        User user = new User();
        user.setId(customerId);

        when(userRepository.findByEmail(customerEmail)).thenReturn(Optional.of(user));
        when(bookingRepository.lockByIdAndCustomerId(bookingId, customerId)).thenReturn(Optional.of(booking));
        when(facilityPolicyService.isReturnNoticeSatisfied(any(), any())).thenReturn(true);

        CheckoutRequest request = new CheckoutRequest();
        LocalDateTime validTime = LocalDateTime.now().plusDays(1).withHour(9).withMinute(0);
        request.setScheduledReturnTime(validTime);
        request.setBankCode("NCB");
        request.setBankAccountNumber("9704198526191432198");
        request.setBankAccountName("NGUYEN VAN A");

        ContractOperationResponse response = service.requestCheckout(bookingId, customerEmail, request);

        assertNotNull(response);
        assertEquals(bookingId, response.getBookingId());
        assertEquals(validTime, booking.getScheduledReturnTime());
        assertEquals("NCB", booking.getRefundBankCode());
        assertEquals("9704198526191432198", booking.getRefundAccountNumber());
        assertEquals("NGUYEN VAN A", booking.getRefundAccountName());
        verify(bookingRepository).save(booking);
    }
}
