package com.storehub.service;

import com.google.zxing.BinaryBitmap;
import com.google.zxing.RGBLuminanceSource;
import com.google.zxing.common.HybridBinarizer;
import com.google.zxing.qrcode.QRCodeReader;
import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.FacilityAccess;
import com.storehub.entity.GatePass;
import com.storehub.entity.StorageUnit;
import com.storehub.entity.User;
import com.storehub.enums.BookingStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.GatePassRepository;
import com.storehub.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.mockito.ArgumentMatchers.eq;
import javax.imageio.ImageIO;
import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class GatePassServiceTest {
    @Mock GatePassRepository passes;
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock FacilityAccess facilityAccess;
    @Mock ActivityLogService activityLog;
    @InjectMocks GatePassService service;

    @Test
    void activeCustomerQrIsScannableAndCanBeUsedOnlyOnce() throws Exception {
        UUID bookingId = UUID.randomUUID(), customerId = UUID.randomUUID();
        UUID facilityId = UUID.randomUUID();
        User customer = new User(); customer.setId(customerId);
        User staff = new User(); staff.setId(UUID.randomUUID());
        Facility facility = Facility.builder().name("Central").build();
        facility.setId(facilityId);
        Booking booking = Booking.builder().bookingCode("BK-123")
                .status(BookingStatus.ACTIVE).endDate(LocalDate.now().plusDays(30))
                .storageUnit(StorageUnit.builder().unitCode("A-01").facility(facility).build())
                .build();
        booking.setId(bookingId);
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(bookingId, customerId))
                .thenReturn(Optional.of(booking));

        var issued = service.issue(bookingId, "customer@test.com");
        verify(passes).revokeUnusedForBooking(eq(bookingId), any(Instant.class));
        ArgumentCaptor<GatePass> captor = ArgumentCaptor.forClass(GatePass.class);
        verify(passes).save(captor.capture());
        GatePass stored = captor.getValue();
        assertEquals(64, stored.getTokenHash().length());
        assertNotEquals(issued.getToken(), stored.getTokenHash());
        assertTrue(issued.getExpiresAt().isAfter(Instant.now()));

        var image = ImageIO.read(new ByteArrayInputStream(
                Base64.getDecoder().decode(issued.getQrPngBase64())));
        int[] pixels = image.getRGB(0, 0, image.getWidth(), image.getHeight(), null, 0, image.getWidth());
        var bitmap = new BinaryBitmap(new HybridBinarizer(
                new RGBLuminanceSource(image.getWidth(), image.getHeight(), pixels)));
        assertEquals(issued.getToken(), new QRCodeReader().decode(bitmap).getText());

        when(facilityAccess.requireForUpdate("staff@test.com", facilityId)).thenReturn(staff);
        when(passes.findBookingIdByTokenHash(stored.getTokenHash())).thenReturn(Optional.of(bookingId));
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));
        when(passes.lockByTokenHash(stored.getTokenHash())).thenReturn(Optional.of(stored));

        var verified = service.verify("staff@test.com", facilityId, issued.getToken());
        assertEquals("A-01", verified.getUnitCode());
        assertNotNull(stored.getUsedAt());
        AppException repeat = assertThrows(AppException.class,
                () -> service.verify("staff@test.com", facilityId, issued.getToken()));
        assertEquals(ErrorCode.GATE_PASS_USED, repeat.getErrorCode());
    }

    @Test
    void confirmedBookingCannotIssueGateQr() {
        UUID bookingId = UUID.randomUUID(), customerId = UUID.randomUUID();
        User customer = new User(); customer.setId(customerId);
        when(users.findByEmail("customer@test.com")).thenReturn(Optional.of(customer));
        when(bookings.lockByIdAndCustomerId(bookingId, customerId))
                .thenReturn(Optional.of(Booking.builder().status(BookingStatus.CONFIRMED).build()));
        AppException error = assertThrows(AppException.class,
                () -> service.issue(bookingId, "customer@test.com"));
        assertEquals(ErrorCode.BOOKING_NOT_CHECKED_IN, error.getErrorCode());
    }

    @Test
    void expiredPassCannotBeVerified() {
        UUID bookingId = UUID.randomUUID(), facilityId = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(facilityId);
        Booking booking = Booking.builder().status(BookingStatus.ACTIVE)
                .endDate(LocalDate.now().plusDays(2))
                .storageUnit(StorageUnit.builder().facility(facility).build()).build();
        GatePass pass = GatePass.builder().facilityId(facilityId)
                .expiresAt(Instant.now().minusSeconds(1)).build();
        User staff = new User(); staff.setId(UUID.randomUUID());
        when(facilityAccess.requireForUpdate("staff@test.com", facilityId)).thenReturn(staff);
        when(passes.findBookingIdByTokenHash(anyString())).thenReturn(Optional.of(bookingId));
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));
        when(passes.lockByTokenHash(anyString())).thenReturn(Optional.of(pass));
        String token = "KMG1." + "a".repeat(43);
        AppException error = assertThrows(AppException.class,
                () -> service.verify("staff@test.com", facilityId, token));
        assertEquals(ErrorCode.GATE_PASS_EXPIRED, error.getErrorCode());
    }
}
