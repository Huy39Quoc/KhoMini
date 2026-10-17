package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.enums.RefundStatus;
import com.storehub.exception.AppException;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.scheduler.RefundDispatcher;
import com.storehub.service.impl.RefundReviewService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RefundReviewPaginationTest {
    @Mock RefundRequestRepository refunds;
    @Mock UserRepository users;
    @Mock RefundDispatcher dispatcher;
    @InjectMocks RefundReviewService service;

    @Test
    void managerCanReachAnOldRefundBeyondTheFirstFifty() {
        UUID facilityId = UUID.randomUUID();
        String manager = "manager@example.invalid";
        when(users.existsByEmailAndRole_NameAndFacility_IdAndIsActiveTrue(
                manager, "FACILITY_MANAGER", facilityId)).thenReturn(true);
        Booking booking = Booking.builder().bookingCode("BK-OLD").build();
        booking.setId(UUID.randomUUID());
        RefundRequest oldRefund = RefundRequest.builder()
                .booking(booking)
                .originalPayment(Payment.builder().transactionId("TXN-OLD").build())
                .status(RefundStatus.MISSING_METADATA)
                .dueAt(LocalDateTime.now().minusDays(2))
                .build();
        oldRefund.setId(UUID.randomUUID());
        when(refunds.findForManager(eq(facilityId), eq(RefundStatus.COMPLETED),
                any(LocalDateTime.class), eq(PageRequest.of(2, 20))))
                .thenReturn(new PageImpl<>(java.util.Collections.nCopies(11, oldRefund),
                        PageRequest.of(2, 20), 51));

        var page = service.list(facilityId, manager, 2, 20);

        assertEquals(51, page.getTotalElements());
        assertEquals(3, page.getTotalPages());
        assertEquals("BK-OLD", page.getContent().get(0).bookingCode());
        assertEquals(true, page.getContent().get(0).overdue());
        verify(refunds).findForManager(eq(facilityId), eq(RefundStatus.COMPLETED),
                any(LocalDateTime.class), eq(PageRequest.of(2, 20)));
    }

    @Test
    void rejectsUnboundedPageSizes() {
        UUID facilityId = UUID.randomUUID();
        String manager = "manager@example.invalid";
        when(users.existsByEmailAndRole_NameAndFacility_IdAndIsActiveTrue(
                manager, "FACILITY_MANAGER", facilityId)).thenReturn(true);
        assertThrows(AppException.class, () -> service.list(facilityId, manager, 0, 101));
    }
}
