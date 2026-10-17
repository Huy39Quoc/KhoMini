package com.storehub.service;

import com.storehub.entity.Booking;
import com.storehub.entity.Facility;
import com.storehub.entity.FacilityPolicy;
import com.storehub.entity.Payment;
import com.storehub.entity.RefundRequest;
import com.storehub.entity.StorageUnit;
import com.storehub.enums.PaymentStatus;
import com.storehub.enums.PaymentType;
import com.storehub.enums.RefundStatus;
import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.FacilityPolicyRepository;
import com.storehub.repository.BookingRepository;
import com.storehub.repository.PaymentRepository;
import com.storehub.repository.RefundRequestRepository;
import com.storehub.repository.UserRepository;
import com.storehub.service.impl.PaymentServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RefundRequestTest {
    @Mock PaymentRepository payments;
    @Mock RefundRequestRepository refunds;
    @Mock BookingRepository bookings;
    @Mock UserRepository users;
    @Mock EmailService email;
    @Mock ActivityLogService logs;
    @Mock PricingService pricing;
    @Mock WaitlistService waitlist;
    @Mock FacilityPolicyRepository facilityPolicies;
    @InjectMocks PaymentServiceImpl service;

    @Test
    void returnQueuesGatewayRefundWithoutPrematurelyMarkingItRefunded() {
        Booking booking = Booking.builder().bookingCode("BK-1")
                .depositPaid(new BigDecimal("200000")).build();
        booking.setId(UUID.randomUUID());
        Payment paid = Payment.builder().booking(booking).paymentType(PaymentType.DEPOSIT)
                .transactionId("TXN-1").amount(new BigDecimal("200000"))
                .gatewayCreateDate("20261009123456")
                .gatewayAmount(new BigDecimal("1000000"))
                .status(PaymentStatus.PAID).build();
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID))
                .thenReturn(Optional.of(paid));
        when(payments.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        assertEquals(new BigDecimal("200000"), service.refundDepositOnReturn(booking));
        assertEquals(new BigDecimal("200000"), booking.getDepositPaid());
        assertEquals(PaymentStatus.PAID, paid.getStatus());
        ArgumentCaptor<RefundRequest> captor = ArgumentCaptor.forClass(RefundRequest.class);
        verify(refunds).save(captor.capture());
        assertEquals(RefundStatus.QUEUED, captor.getValue().getStatus());
        assertEquals(PaymentStatus.REFUND_PENDING,
                captor.getValue().getRefundPayment().getStatus());
        assertEquals(5, java.time.Duration.between(
                captor.getValue().getUpdatedStatusAt(), captor.getValue().getDueAt()).toDays());
    }

    @Test
    void snapshotsFacilityRefundDeadlineAtRequestCreation() {
        Facility facility = Facility.builder().build();
        facility.setId(UUID.randomUUID());
        Booking booking = Booking.builder().bookingCode("BK-SLA")
                .storageUnit(StorageUnit.builder().facility(facility).build())
                .depositPaid(new BigDecimal("100")).build();
        booking.setId(UUID.randomUUID());
        Payment original = Payment.builder().booking(booking)
                .paymentType(PaymentType.DEPOSIT).status(PaymentStatus.PAID)
                .transactionId("TXN-SLA").amount(new BigDecimal("100"))
                .gatewayCreateDate("20261009123456").build();
        when(facilityPolicies.findByFacility_Id(facility.getId()))
                .thenReturn(Optional.of(FacilityPolicy.builder().depositRefundSlaDays(2).build()));
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID))
                .thenReturn(Optional.of(original));
        when(payments.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.refundDeposit(booking, new BigDecimal("100"));

        ArgumentCaptor<RefundRequest> captured = ArgumentCaptor.forClass(RefundRequest.class);
        verify(refunds).save(captured.capture());
        LocalDateTime due = captured.getValue().getDueAt();
        assertEquals(captured.getValue().getUpdatedStatusAt().plusDays(2), due);
    }

    @Test
    void legacyPaymentWithoutGatewayDateRequiresManualReconciliation() {
        Booking booking = Booking.builder().depositPaid(new BigDecimal("100"))
                .bookingCode("BK-OLD").build();
        booking.setId(UUID.randomUUID());
        Payment old = Payment.builder().booking(booking)
                .paymentType(PaymentType.DEPOSIT).status(PaymentStatus.PAID)
                .transactionId("TXN-OLD").build();
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID))
                .thenReturn(Optional.of(old));
        when(payments.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.refundDeposit(booking, new BigDecimal("100"));

        ArgumentCaptor<RefundRequest> captor = ArgumentCaptor.forClass(RefundRequest.class);
        verify(refunds).save(captor.capture());
        assertEquals(RefundStatus.MISSING_METADATA, captor.getValue().getStatus());
    }

    @Test
    void refundedExtensionChargeDoesNotBlockDepositRefundOnReturn() {
        Booking booking = Booking.builder().bookingCode("BK-EXT")
                .depositPaid(new BigDecimal("200000")).build();
        booking.setId(UUID.randomUUID());
        Payment deposit = Payment.builder().booking(booking).paymentType(PaymentType.DEPOSIT)
                .transactionId("TXN-DEPOSIT").amount(new BigDecimal("200000"))
                .gatewayCreateDate("20261009123456")
                .status(PaymentStatus.PAID).build();
        deposit.setId(UUID.randomUUID());

        // A previous refund of an EXTRA_CHARGE belongs to this booking, but
        // must not consume the deposit transaction's one allowed refund.
        lenient().when(refunds.existsByBooking_Id(booking.getId())).thenReturn(true);
        when(refunds.existsByOriginalPayment_Id(deposit.getId())).thenReturn(false);
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID))
                .thenReturn(Optional.of(deposit));
        when(payments.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

        assertEquals(new BigDecimal("200000"), service.refundDepositOnReturn(booking));

        ArgumentCaptor<RefundRequest> captor = ArgumentCaptor.forClass(RefundRequest.class);
        verify(refunds).save(captor.capture());
        assertEquals(deposit.getId(), captor.getValue().getOriginalPayment().getId());
        assertEquals(RefundStatus.QUEUED, captor.getValue().getStatus());
        verify(refunds, never()).existsByBooking_Id(booking.getId());
    }

    @Test
    void aSecondRefundForTheSameDepositIsStillRejected() {
        Booking booking = Booking.builder().bookingCode("BK-DUPLICATE")
                .depositPaid(new BigDecimal("200000")).build();
        booking.setId(UUID.randomUUID());
        Payment deposit = Payment.builder().booking(booking).paymentType(PaymentType.DEPOSIT)
                .transactionId("TXN-DEPOSIT").amount(new BigDecimal("200000"))
                .status(PaymentStatus.PAID).build();
        deposit.setId(UUID.randomUUID());
        when(payments.findFirstByBooking_IdAndPaymentTypeAndStatusOrderByPaymentTimeDesc(
                booking.getId(), PaymentType.DEPOSIT, PaymentStatus.PAID))
                .thenReturn(Optional.of(deposit));
        when(refunds.existsByOriginalPayment_Id(deposit.getId())).thenReturn(true);

        AppException error = assertThrows(AppException.class,
                () -> service.refundDepositOnReturn(booking));

        assertEquals(ErrorCode.PAYMENT_ALREADY_PROCESSED, error.getErrorCode());
        verify(refunds, never()).save(any(RefundRequest.class));
        verify(payments, never()).save(any(Payment.class));
    }
}
