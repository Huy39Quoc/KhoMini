package com.storehub.integration;

import com.storehub.exception.AppException;
import com.storehub.exception.ErrorCode;
import com.storehub.repository.BookingRepository;
import com.storehub.scheduler.RefundDispatcher;
import com.storehub.service.EmailService;
import com.storehub.service.impl.FacilityOperationsServiceImpl;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ContextConfiguration;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.sql.Timestamp;
import java.util.UUID;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@AutoConfigureMockMvc
@ContextConfiguration(initializers = DisposableDatabaseGuard.class)
@EnabledIfEnvironmentVariable(named = "STOREHUB_INTEGRATION_TEST", matches = "true")
class AppointmentConflictDatabaseTest {
    @Autowired JdbcTemplate jdbc;
    @Autowired BookingRepository bookings;
    @Autowired FacilityOperationsServiceImpl operations;
    @MockBean EmailService email;
    @MockBean RefundDispatcher refunds;

    @Test
    void detectsCrossTypeConflictsFallbackTimesAndOnlyOpenAppointments() {
        Fixture first = fixture();
        UUID otherBooking = UUID.randomUUID();
        operations.assignAppointment(first.bookingId(), first.facilityId(), first.managerEmail(), "CHECK_IN", first.staffId());
        // Assigning the same staff to the same appointment is idempotent.
        operations.assignAppointment(first.bookingId(), first.facilityId(), first.managerEmail(), "CHECK_IN", first.staffId());
        assertTrue(conflict(first, otherBooking, first.time()));
        assertFalse(conflict(first, first.bookingId(), first.time()));
        assertFalse(conflict(first, otherBooking, first.time().plusMinutes(1)));
        assertFalse(conflict(first, otherBooking, first.time().plusDays(1)));
        assertFalse(bookings.existsConflictingStaffAppointment(UUID.randomUUID(), otherBooking,
                first.time(), first.time().plusMinutes(1)));

        jdbc.update("UPDATE bookings SET status = 'CANCELLED' WHERE id = ?", first.bookingId());
        assertFalse(conflict(first, otherBooking, first.time()));
        jdbc.update("""
                UPDATE bookings SET status = 'ACTIVE', assigned_check_out_staff_id = ?,
                scheduled_return_time = ?, end_date = ? WHERE id = ?
                """, first.staffId(), Timestamp.valueOf(first.time().plusSeconds(45)),
                first.time().toLocalDate(), first.bookingId());
        assertTrue(conflict(first, otherBooking, first.time()));
        jdbc.update("UPDATE bookings SET scheduled_return_time = NULL WHERE id = ?", first.bookingId());
        assertTrue(conflict(first, otherBooking, first.time())); // Default checkout is 09:00.
        jdbc.update("UPDATE bookings SET status = 'COMPLETED' WHERE id = ?", first.bookingId());
        assertFalse(conflict(first, otherBooking, first.time()));
        jdbc.update("UPDATE bookings SET status = 'CONFIRMED', scheduled_check_in_time = NULL WHERE id = ?", first.bookingId());
        LocalDateTime fallback = jdbc.queryForObject("""
                SELECT b.start_date + COALESCE(f.open_time, TIME '08:00:00')
                FROM bookings b JOIN storage_units s ON s.id = b.storage_unit_id
                JOIN facilities f ON f.id = s.facility_id WHERE b.id = ?
                """, Timestamp.class, first.bookingId()).toLocalDateTime();
        assertTrue(conflict(first, otherBooking, fallback));
    }

    @Test
    void simultaneousAssignmentsToTheSameStaffAndMinuteAllowOnlyOneBooking() throws Exception {
        Fixture first = fixture();
        Fixture second = fixture(first.time());
        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        try {
            Future<Boolean> a = pool.submit(() -> assignConcurrently(first, ready, start));
            Future<Boolean> b = pool.submit(() -> assignConcurrently(second, ready, start));
            assertTrue(ready.await(10, TimeUnit.SECONDS));
            start.countDown();
            assertNotEquals(a.get(20, TimeUnit.SECONDS), b.get(20, TimeUnit.SECONDS));
            assertEquals(1, jdbc.queryForObject("""
                    SELECT COUNT(*) FROM bookings WHERE id IN (?, ?) AND assigned_check_in_staff_id = ?
                    """, Integer.class, first.bookingId(), second.bookingId(), first.staffId()));
        } finally {
            start.countDown();
            pool.shutdownNow();
        }
    }

    private boolean assignConcurrently(Fixture fixture, CountDownLatch ready, CountDownLatch start) throws Exception {
        ready.countDown();
        assertTrue(start.await(10, TimeUnit.SECONDS));
        try {
            operations.assignAppointment(fixture.bookingId(), fixture.facilityId(), fixture.managerEmail(),
                    "CHECK_IN", fixture.staffId());
            return true;
        } catch (AppException error) {
            assertEquals(ErrorCode.STAFF_APPOINTMENT_CONFLICT, error.getErrorCode());
            return false;
        }
    }

    private boolean conflict(Fixture fixture, UUID excludedBooking, LocalDateTime time) {
        LocalDateTime minute = time.truncatedTo(java.time.temporal.ChronoUnit.MINUTES);
        return bookings.existsConflictingStaffAppointment(fixture.staffId(), excludedBooking, minute, minute.plusMinutes(1));
    }

    private Fixture fixture() {
        // Each test gets a separate day so it never depends on method execution order.
        LocalDate day = jdbc.queryForObject("""
                SELECT GREATEST(COALESCE(MAX(start_date), CURRENT_DATE), CURRENT_DATE) + 1 FROM bookings
                """, java.sql.Date.class).toLocalDate();
        return fixture(day.atTime(9, 0));
    }

    private Fixture fixture(LocalDateTime time) {
        String database = jdbc.queryForObject("SELECT current_database()", String.class);
        assertTrue(database != null && database.startsWith("storehub_it_"));
        var source = jdbc.queryForMap("""
                SELECT b.assigned_check_in_staff_id AS staff_id, s.facility_id, m.email AS manager_email
                FROM bookings b JOIN storage_units s ON s.id = b.storage_unit_id
                JOIN facilities f ON f.id = s.facility_id JOIN users m ON m.id = f.manager_id
                WHERE b.booking_code = 'BK-TEST-CONFIRMED-01'
                """);
        UUID id = UUID.randomUUID(), unitId = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO storage_units SELECT (jsonb_populate_record(NULL::storage_units,
                    to_jsonb(s) || jsonb_build_object('id', CAST(? AS text),
                        'unit_code', CAST(? AS text), 'status', 'RESERVED'))).*
                FROM storage_units s JOIN bookings b ON b.storage_unit_id = s.id
                WHERE b.booking_code = 'BK-TEST-CONFIRMED-01'
                """, unitId, "AP-" + unitId.toString().substring(0, 12));
        jdbc.update("""
                INSERT INTO bookings SELECT (jsonb_populate_record(NULL::bookings,
                    to_jsonb(b) || jsonb_build_object('id', CAST(? AS text),
                        'booking_code', CAST(? AS text), 'storage_unit_id', CAST(? AS text),
                        'start_date', CAST(? AS text), 'end_date', CAST(? AS text),
                        'scheduled_check_in_time', CAST(? AS text),
                        'assigned_check_in_staff_id', NULL, 'assigned_check_out_staff_id', NULL))).*
                FROM bookings b WHERE b.booking_code = 'BK-TEST-CONFIRMED-01'
                """, id, "BK-AP-" + id.toString().substring(0, 20), unitId,
                time.toLocalDate().toString(), time.toLocalDate().plusMonths(1).toString(), time.toString());
        return new Fixture(id, (UUID) source.get("facility_id"), (UUID) source.get("staff_id"),
                source.get("manager_email").toString(), time);
    }

    private record Fixture(UUID bookingId, UUID facilityId, UUID staffId, String managerEmail, LocalDateTime time) {}
}
