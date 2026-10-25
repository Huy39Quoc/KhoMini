package com.storehub.integration;

import com.storehub.dto.request.*;
import com.storehub.enums.*;
import com.storehub.service.*;
import com.storehub.service.impl.FacilityOperationsServiceImpl;
import com.storehub.scheduler.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ContextConfiguration;
import java.math.BigDecimal;
import java.time.*;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@AutoConfigureMockMvc
@ContextConfiguration(initializers = DisposableDatabaseGuard.class)
@EnabledIfEnvironmentVariable(named = "STOREHUB_INTEGRATION_TEST", matches = "true")
class HandoverIssueDatabaseTest {
    @Autowired JdbcTemplate jdbc;
    @Autowired FacilityOperationsServiceImpl operations;
    @Autowired HandoverIssueService issues;
    @Autowired BookingService bookingService;
    @Autowired UnclaimedBookingExpiryScheduler expiry;
    @MockBean EmailService email;
    @MockBean RefundDispatcher refunds;

    @Test void customerCancellationAfterRejectedHandoverRefundsEveryPrepaidDongWithoutPenalty() {
        Fixture f = rejected();
        // Even when the original rental has ended, the 48-hour issue window protects the customer.
        jdbc.update("UPDATE bookings SET end_date = CURRENT_DATE WHERE id = ?", f.id());
        expiry.expireUnclaimedBookings();
        assertEquals("CONFIRMED", status(f));
        bookingService.cancelBooking(f.id(), f.customerEmail());
        assertFullRefund(f);
    }

    @Test void unresolvedIssueExpiresBeforeOriginalRentalEndAndQueuesOnlyOneFullRefund() {
        Fixture f = rejected();
        jdbc.update("UPDATE bookings SET handover_issue_due_at = CURRENT_TIMESTAMP - interval '1 hour' WHERE id = ?", f.id());
        expiry.expireUnclaimedBookings(); expiry.expireUnclaimedBookings();
        assertFullRefund(f);
    }

    @Test void managerReplacesBrokenUnitWithConsentAndStaffCanCompleteTheNewHandover() {
        Fixture f = rejected();
        UUID replacement = cloneUnit("AVAILABLE");
        HandoverIssueResolutionRequest request = new HandoverIssueResolutionRequest();
        request.setAction(HandoverIssueResolutionRequest.Action.REPLACE_UNIT);
        request.setReplacementUnitId(replacement); request.setCustomerAgreed(true);
        request.setNotes("Khách xác nhận qua điện thoại; đổi ngăn cùng loại, không thu thêm");
        LocalDateTime appointment = LocalDate.now().plusDays(1).atTime(9, 0);
        request.setScheduledCheckInTime(appointment);
        issues.resolve(f.facilityId(), f.id(), f.managerEmail(), request);
        assertEquals("ARRANGED", jdbc.queryForObject("SELECT handover_issue_status FROM bookings WHERE id = ?", String.class, f.id()));
        assertEquals(appointment.toLocalDate().plusMonths(1), jdbc.queryForObject(
                "SELECT end_date FROM bookings WHERE id = ?", java.sql.Date.class, f.id()).toLocalDate());
        assertEquals("UNDER_MAINTENANCE", jdbc.queryForObject("SELECT status FROM storage_units WHERE id = ?", String.class, f.unitId()));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM refund_requests WHERE booking_id = ?", Integer.class, f.id()));
        // Move only the appointment in the disposable DB to simulate its arrival.
        jdbc.update("UPDATE bookings SET start_date = CURRENT_DATE, scheduled_check_in_time = CURRENT_TIMESTAMP - interval '1 minute' WHERE id = ?", f.id());
        operations.checkIn(f.id(), f.facilityId(), f.staffEmail(), HandoverRequest.builder()
                .unitCondition(HandoverUnitCondition.GOOD).lockCondition(HandoverLockCondition.LOCKED_WORKING).build());
        assertEquals("ACTIVE", status(f));
        assertEquals("RESOLVED", jdbc.queryForObject("SELECT handover_issue_status FROM bookings WHERE id = ?", String.class, f.id()));
        assertEquals("OCCUPIED", jdbc.queryForObject("SELECT status FROM storage_units WHERE id = ?", String.class, replacement));
    }

    private void assertFullRefund(Fixture f) {
        assertEquals("CANCELLED", status(f));
        assertEquals("CANCELLED", jdbc.queryForObject("SELECT handover_issue_status FROM bookings WHERE id = ?", String.class, f.id()));
        assertEquals("UNDER_MAINTENANCE", jdbc.queryForObject("SELECT status FROM storage_units WHERE id = ?", String.class, f.unitId()));
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM refund_requests WHERE booking_id = ?", Integer.class, f.id()));
        assertEquals(0, f.paid().compareTo(jdbc.queryForObject("SELECT amount FROM refund_requests WHERE booking_id = ?", BigDecimal.class, f.id())));
        assertNotEquals("COMPLETED", jdbc.queryForObject("SELECT status FROM refund_requests WHERE booking_id = ?", String.class, f.id()));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM deposit_deductions WHERE booking_id = ?", Integer.class, f.id()));
    }

    private String status(Fixture f) { return jdbc.queryForObject("SELECT status FROM bookings WHERE id = ?", String.class, f.id()); }

    private UUID cloneUnit(String state) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO storage_units SELECT (jsonb_populate_record(NULL::storage_units,
                to_jsonb(s) || jsonb_build_object('id', CAST(? AS text), 'unit_code', CAST(? AS text), 'status', CAST(? AS text)))).*
                FROM storage_units s JOIN bookings b ON b.storage_unit_id = s.id
                WHERE b.booking_code = 'BK-TEST-CONFIRMED-01'
                """, id, "HI-" + id.toString().substring(0, 12), state);
        return id;
    }

    private Fixture rejected() {
        assertTrue(jdbc.queryForObject("SELECT current_database()", String.class).startsWith("storehub_it_"));
        var source = jdbc.queryForMap("""
                SELECT s.facility_id, staff.email AS staff_email, manager.email AS manager_email, c.email AS customer_email
                FROM bookings b JOIN storage_units s ON s.id = b.storage_unit_id
                JOIN users staff ON staff.id = b.assigned_check_in_staff_id
                JOIN users c ON c.id = b.customer_id JOIN facilities f ON f.id = s.facility_id
                JOIN users manager ON manager.id = f.manager_id WHERE b.booking_code = 'BK-TEST-CONFIRMED-01'
                """);
        UUID id = UUID.randomUUID(), unitId = cloneUnit("RESERVED");
        jdbc.update("""
                INSERT INTO bookings SELECT (jsonb_populate_record(NULL::bookings, to_jsonb(b) || jsonb_build_object(
                'id', CAST(? AS text), 'booking_code', CAST(? AS text), 'storage_unit_id', CAST(? AS text),
                'start_date', (CURRENT_DATE - 1)::text, 'end_date', (CURRENT_DATE + 29)::text,
                'scheduled_check_in_time', (CURRENT_TIMESTAMP - interval '1 day')::timestamp::text))).*
                FROM bookings b WHERE b.booking_code = 'BK-TEST-CONFIRMED-01'
                """, id, "BK-HI-" + id.toString().substring(0, 20), unitId);
        jdbc.update("""
                INSERT INTO payments SELECT (jsonb_populate_record(NULL::payments, to_jsonb(p) || jsonb_build_object(
                'id', gen_random_uuid()::text, 'booking_id', CAST(? AS text),
                'transaction_id', CAST(? AS text) || p.payment_type))).*
                FROM payments p JOIN bookings b ON b.id = p.booking_id
                WHERE b.booking_code = 'BK-TEST-CONFIRMED-01' AND p.status = 'PAID'
                """, id, "HI-" + id + "-");
        BigDecimal paid = jdbc.queryForObject("SELECT SUM(amount) FROM payments WHERE booking_id = ?", BigDecimal.class, id);
        operations.checkIn(id, (UUID) source.get("facility_id"), source.get("staff_email").toString(),
                HandoverRequest.builder().unitCondition(HandoverUnitCondition.DAMAGED)
                        .lockCondition(HandoverLockCondition.BROKEN).notes("Khách đã đến; khóa và ngăn hỏng do cơ sở").build());
        assertEquals("OPEN", jdbc.queryForObject("SELECT handover_issue_status FROM bookings WHERE id = ?", String.class, id));
        return new Fixture(id, unitId, (UUID) source.get("facility_id"), source.get("staff_email").toString(),
                source.get("manager_email").toString(), source.get("customer_email").toString(), paid);
    }

    private record Fixture(UUID id, UUID unitId, UUID facilityId, String staffEmail, String managerEmail, String customerEmail, BigDecimal paid) {}
}
