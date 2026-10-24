package com.storehub.service;

import com.storehub.dto.request.ConfirmBankTransferRequest;
import com.storehub.entity.*;
import com.storehub.enums.*;
import com.storehub.exception.AppException;
import com.storehub.repository.*;
import com.storehub.scheduler.RefundDispatcher;
import com.storehub.service.impl.RefundReviewService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.math.BigDecimal;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DepositRefundSettlementTest {
    @Mock RefundRequestRepository refunds;
    @Mock UserRepository users;
    @Mock BookingRepository bookings;
    @Mock RefundDispatcher dispatcher;
    @InjectMocks RefundReviewService service;

    @Test
    void confirmedRefundClosesRemainingBalanceWithoutDeductingDamageTwice() {
        UUID facilityId = UUID.randomUUID(), bookingId = UUID.randomUUID(), refundId = UUID.randomUUID();
        Facility facility = new Facility(); facility.setId(facilityId);
        Booking booking = Booking.builder().depositPaid(new BigDecimal("800"))
                .storageUnit(StorageUnit.builder().facility(facility).build()).build();
        booking.setId(bookingId);
        Payment original = Payment.builder().amount(new BigDecimal("1000"))
                .paymentType(PaymentType.DEPOSIT).status(PaymentStatus.PAID).build();
        RefundRequest refund = RefundRequest.builder().booking(booking).originalPayment(original)
                .refundPayment(Payment.builder().build()).amount(new BigDecimal("800"))
                .depositAmount(new BigDecimal("800")).damageDeduction(new BigDecimal("200"))
                .status(RefundStatus.AWAITING_BANK_TRANSFER).build();
        refund.setId(refundId);
        when(users.existsByEmailAndRole_NameAndFacility_IdAndIsActiveTrue("manager@test.com", "FACILITY_MANAGER", facilityId)).thenReturn(true);
        when(refunds.lockById(refundId)).thenReturn(Optional.of(refund));
        when(bookings.lockById(bookingId)).thenReturn(Optional.of(booking));
        var confirmation = ConfirmBankTransferRequest.builder().transferReference("BANK-123").build();

        service.confirmBankTransfer(facilityId, refundId, "manager@test.com", confirmation);

        assertEquals(BigDecimal.ZERO, booking.getDepositPaid());
        assertEquals(RefundStatus.COMPLETED, refund.getStatus());
        assertNotNull(refund.getCompletedAt());
        assertThrows(AppException.class,
                () -> service.confirmBankTransfer(facilityId, refundId, "manager@test.com", confirmation));
        assertEquals(BigDecimal.ZERO, booking.getDepositPaid());
        verify(bookings, times(1)).lockById(bookingId);
    }
}
