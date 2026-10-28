package com.storehub.integration;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.storehub.dto.response.RevenueReportResponse;
import com.storehub.service.EmailService;
import com.storehub.service.ReportService;
import com.storehub.scheduler.RefundDispatcher;
import com.storehub.util.VNPayUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.ContextConfiguration;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Run only against a disposable PostgreSQL database named storehub_it_* (see STEP6_VERIFICATION.md). */
@SpringBootTest
@AutoConfigureMockMvc
@ContextConfiguration(initializers = DisposableDatabaseGuard.class)
@EnabledIfEnvironmentVariable(named = "STOREHUB_INTEGRATION_TEST", matches = "true")
class ReservationDatabaseFlowTest {
    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper json;
    @Autowired ReportService reports;
    @Autowired com.storehub.scheduler.UnclaimedBookingExpiryScheduler unclaimedExpiry;
    @MockBean EmailService emailService;
    @MockBean RefundDispatcher refundDispatcher;

    @BeforeEach
    void ensureDisposableDatabase() {
        String database = jdbc.queryForObject("select current_database()", String.class);
        assertTrue(database != null && database.startsWith("storehub_it_"),
                "Integration test writes data. Use a disposable DB named storehub_it_*.");
    }

    @Test
    void sameFacilityCannotHaveTwoPhysicalUnitsWithTheSameCode() {
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from pg_constraint where conname = 'uq_storage_units_facility_code'",
                Integer.class));
        assertThrows(DataIntegrityViolationException.class, () -> jdbc.update("""
                INSERT INTO storage_units
                    (id, created_at, updated_at, unit_code, floor_level, status, facility_id, unit_type_id)
                SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
                       unit_code, floor_level, 'AVAILABLE', facility_id, unit_type_id
                FROM storage_units LIMIT 1
                """));
    }

    @Test
    void paidUnclaimedReservationsExpireAtomicallyWithContractSettlementAndNoDuplicateMoney() {
        LocalDate today = LocalDate.now(java.time.ZoneId.of("Asia/Ho_Chi_Minh"));
        for (boolean fullRefund : new boolean[]{false, true}) {
            UUID id = UUID.randomUUID();
            UUID unitId = UUID.randomUUID();
            jdbc.update("""
                    INSERT INTO storage_units SELECT (jsonb_populate_record(NULL::storage_units,
                        to_jsonb(s) || jsonb_build_object('id', CAST(? AS text),
                            'unit_code', CAST(? AS text), 'status', 'RESERVED'))).*
                    FROM storage_units s JOIN bookings b ON b.storage_unit_id = s.id
                    WHERE b.booking_code = 'BK-TEST-CONFIRMED-01'
                    """, unitId, "NS-" + unitId.toString().substring(0, 12));
            // Clone a valid paid contract so all historical policy fields are real.
            jdbc.update("""
                    INSERT INTO bookings SELECT (jsonb_populate_record(NULL::bookings,
                        to_jsonb(b) || jsonb_build_object(
                            'id', CAST(? AS text), 'booking_code', CAST(? AS text),
                            'storage_unit_id', CAST(? AS text), 'start_date', CAST(? AS text),
                            'scheduled_check_in_time', CAST(? AS text), 'end_date', CAST(? AS text),
                            'cancellation_full_refund_hours', CAST(? AS integer),
                            'handover_time', NULL, 'handed_over_by_staff_id', NULL))).*
                    FROM bookings b WHERE b.booking_code = 'BK-TEST-CONFIRMED-01'
                    """, id, "BK-NS-" + id.toString().substring(0, 20), unitId,
                    today.minusMonths(1).toString(), today.minusMonths(1).atTime(9, 0).toString(),
                    today.plusDays(1).toString(), fullRefund ? Integer.MIN_VALUE : 48);
            jdbc.update("""
                    INSERT INTO payments SELECT (jsonb_populate_record(NULL::payments,
                        to_jsonb(p) || jsonb_build_object('id', gen_random_uuid()::text,
                            'booking_id', CAST(? AS text),
                            'transaction_id', CAST(? AS text) || p.payment_type))).*
                    FROM payments p JOIN bookings b ON b.id = p.booking_id
                    WHERE b.booking_code = 'BK-TEST-CONFIRMED-01' AND p.status = 'PAID'
                    """, id, "NS-" + id + "-");
            BigDecimal deposit = jdbc.queryForObject("SELECT deposit_paid FROM bookings WHERE id = ?", BigDecimal.class, id);
            BigDecimal paid = jdbc.queryForObject("SELECT SUM(amount) FROM payments WHERE booking_id = ?", BigDecimal.class, id);

            assertTrue(!jdbc.queryForList("""
                    SELECT id FROM bookings WHERE status = 'CONFIRMED'
                    AND end_date <= ? AND handover_time IS NULL AND handed_over_by_staff_id IS NULL
                    """, UUID.class, today).contains(id));
            jdbc.update("UPDATE bookings SET end_date = ? WHERE id = ?", today, id);
            unclaimedExpiry.expireUnclaimedBookings();
            unclaimedExpiry.expireUnclaimedBookings();

            assertEquals("CANCELLED", jdbc.queryForObject("SELECT status FROM bookings WHERE id = ?", String.class, id));
            assertEquals("AVAILABLE", jdbc.queryForObject("SELECT status FROM storage_units WHERE id = ?", String.class, unitId));
            assertEquals(1, jdbc.queryForObject("""
                    SELECT COUNT(*) FROM activity_logs WHERE resource_id = ? AND action = 'RESERVATION_EXPIRE'
                    """, Integer.class, id));
            assertEquals(fullRefund ? 1 : 0, jdbc.queryForObject(
                    "SELECT COUNT(*) FROM refund_requests WHERE booking_id = ?", Integer.class, id));
            assertEquals(fullRefund ? 0 : 1, jdbc.queryForObject(
                    "SELECT COUNT(*) FROM deposit_deductions WHERE booking_id = ?", Integer.class, id));
            if (fullRefund) {
                assertEquals(0, paid.compareTo(jdbc.queryForObject(
                        "SELECT amount FROM refund_requests WHERE booking_id = ?", BigDecimal.class, id)));
                assertEquals(0, deposit.compareTo(jdbc.queryForObject(
                        "SELECT deposit_paid FROM bookings WHERE id = ?", BigDecimal.class, id)));
                assertTrue(!"COMPLETED".equals(jdbc.queryForObject(
                        "SELECT status FROM refund_requests WHERE booking_id = ?", String.class, id)));
            } else {
                assertEquals(0, deposit.compareTo(jdbc.queryForObject(
                        "SELECT amount FROM deposit_deductions WHERE booking_id = ?", BigDecimal.class, id)));
                assertEquals(0, jdbc.queryForObject("SELECT deposit_paid FROM bookings WHERE id = ?",
                        BigDecimal.class, id).signum());
            }
        }
    }

    @Test
    void migrationsAuthReservationPaymentAttemptAndCancellation() throws Exception {
        // Các migration V1..V30 cũ đã được gộp thành V1; V2 bảo vệ mã ngăn trong từng cơ sở.
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from flyway_schema_history where version = '1' and success = true",
                Integer.class));
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from pg_constraint where conname = 'uq_storage_units_facility_code'",
                Integer.class));

        Map<String, String> available = jdbc.queryForMap("""
                select f.id::text as facility_id, s.unit_type_id::text as unit_type_id
                from storage_units s join facilities f on f.id = s.facility_id
                where f.status = 'ACTIVE' and s.status = 'AVAILABLE'
                limit 1
                """).entrySet().stream().collect(java.util.stream.Collectors.toMap(
                        Map.Entry::getKey, e -> e.getValue().toString()));

        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 12);
        String email = "it-" + suffix + "@example.invalid";
        String password = "TestOnlyPassword123!";
        mvc.perform(post("/api/v1/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("username", "it" + suffix,
                        "email", email, "password", password, "fullName", "Integration Test",
                        "phone", "0371234567"))))
                .andExpect(status().isCreated());

        String login = mvc.perform(post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("email", email, "password", password))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String token = json.readTree(login).path("data").path("accessToken").asText();
        assertTrue(!token.isBlank());

        mvc.perform(get("/api/v1/catalog/facilities"))
                .andExpect(status().isOk());

        String policyBody = mvc.perform(get("/api/v1/facility-policies/by-facility/" + available.get("facility_id"))
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        JsonNode acceptedPolicy = json.readTree(policyBody).path("data");
        String booked = mvc.perform(post("/api/v1/bookings")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of(
                        "facilityId", available.get("facility_id"),
                        "unitTypeId", available.get("unit_type_id"),
                        "startDate", LocalDate.now().plusDays(2).toString(),
                        "rentalMonths", 1,
                        "prohibitedItemsConfirmed", true,
                        "termsConfirmed", true,
                        "termsVersion", acceptedPolicy.path("termsVersion").asText(),
                        "termsHash", acceptedPolicy.path("termsHash").asText()))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        JsonNode booking = json.readTree(booked).path("data");
        UUID bookingId = UUID.fromString(booking.path("id").asText());
        UUID unitId = UUID.fromString(booking.path("storageUnitId").asText());

        String started = mvc.perform(post("/api/v1/payments/initiate")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("bookingId", bookingId,
                        "paymentType", "DEPOSIT"))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        JsonNode payment = json.readTree(started).path("data");
        assertEquals("PENDING", payment.path("status").asText());
        assertTrue(payment.path("paymentUrl").asText().contains("vnp_TxnRef="));

        mvc.perform(delete("/api/v1/bookings/{id}", bookingId)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
        assertEquals("CANCELLED", jdbc.queryForObject(
                "select status from bookings where id = ?", String.class, bookingId));
        assertEquals("AVAILABLE", jdbc.queryForObject(
                "select status from storage_units where id = ?", String.class, unitId));

        // A signed IPN received after cancellation must queue a full refund,
        // without reviving the booking or reserving the released unit again.
        String txn = payment.path("transactionId").asText();
        String amount = new BigDecimal(payment.path("amount").asText())
                .movePointRight(2).toBigIntegerExact().toString();
        String callbackData = "vnp_Amount=" + amount
                + "&vnp_ResponseCode=00&vnp_TransactionStatus=00&vnp_TxnRef=" + txn;
        String signature = VNPayUtil.hmacSHA512(System.getenv("VNPAY_HASH_SECRET"), callbackData);
        for (int i = 0; i < 2; i++) {
            String response = mvc.perform(get("/api/v1/payments/vnpay-ipn")
                    .param("vnp_Amount", amount)
                    .param("vnp_ResponseCode", "00")
                    .param("vnp_TransactionStatus", "00")
                    .param("vnp_TxnRef", txn)
                    .param("vnp_SecureHash", signature))
                    .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
            assertEquals("00", json.readTree(response).path("RspCode").asText());
        }
        assertEquals("CANCELLED", jdbc.queryForObject(
                "select status from bookings where id = ?", String.class, bookingId));
        assertEquals("AVAILABLE", jdbc.queryForObject(
                "select status from storage_units where id = ?", String.class, unitId));
        assertEquals("REFUND_PENDING", jdbc.queryForObject(
                "select status from payments where transaction_id = ?", String.class, txn));
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from refund_requests where booking_id = ?", Integer.class, bookingId));
        assertEquals(0, jdbc.queryForObject(
                "select amount from refund_requests where booking_id = ?", BigDecimal.class, bookingId)
                .compareTo(new BigDecimal(payment.path("amount").asText())));

        // A refund completed next month must not erase the original charge
        // from the month in which the gateway captured it.
        LocalDate chargeDate = LocalDate.of(2010, 1, 15);
        LocalDate refundDate = LocalDate.of(2010, 2, 10);
        UUID facilityId = UUID.fromString(available.get("facility_id"));
        RevenueReportResponse chargeBaseline = reports.getRevenueReport(chargeDate, chargeDate);
        RevenueReportResponse refundBaseline = reports.getRevenueReport(refundDate, refundDate);
        BigDecimal deposit = jdbc.queryForObject(
                "select amount from payments where transaction_id = ?", BigDecimal.class, txn);
        BigDecimal rental = jdbc.queryForObject(
                "select amount from payments where transaction_id = ?", BigDecimal.class, txn + "-R");
        jdbc.update("update payments set payment_time = ? where transaction_id in (?, ?)",
                Timestamp.valueOf(chargeDate.atTime(12, 0)), txn, txn + "-R");

        RevenueReportResponse before = reports.getRevenueReport(chargeDate, chargeDate);
        assertEquals(0, rental.compareTo(before.getSystemSummary().getTotalRevenue()
                .subtract(chargeBaseline.getSystemSummary().getTotalRevenue())));
        assertEquals(0, deposit.compareTo(before.getSystemSummary().getDepositRevenue()
                .subtract(chargeBaseline.getSystemSummary().getDepositRevenue())));

        jdbc.update("update payments set status = 'REFUNDED' where transaction_id in (?, ?)",
                txn, txn + "-R");
        jdbc.update("update refund_requests set status = 'COMPLETED', completed_at = ? where booking_id = ?",
                Timestamp.valueOf(LocalDateTime.of(2010, 2, 10, 12, 0)), bookingId);

        RevenueReportResponse originalPeriod = reports.getRevenueReport(chargeDate, chargeDate);
        RevenueReportResponse refundPeriod = reports.getRevenueReport(refundDate, refundDate);
        assertEquals(0, before.getSystemSummary().getTotalRevenue()
                .compareTo(originalPeriod.getSystemSummary().getTotalRevenue()));
        assertEquals(0, before.getSystemSummary().getDepositRevenue()
                .compareTo(originalPeriod.getSystemSummary().getDepositRevenue()));
        assertEquals(0, rental.negate().compareTo(refundPeriod.getSystemSummary().getTotalRevenue()
                .subtract(refundBaseline.getSystemSummary().getTotalRevenue())));
        assertEquals(0, deposit.negate().compareTo(refundPeriod.getSystemSummary().getDepositRevenue()
                .subtract(refundBaseline.getSystemSummary().getDepositRevenue())));
        assertEquals(0, rental.negate().compareTo(facilityRevenue(refundPeriod, facilityId)
                .subtract(facilityRevenue(refundBaseline, facilityId))));
    }

    private BigDecimal facilityRevenue(RevenueReportResponse report, UUID facilityId) {
        return report.getByFacility().stream()
                .filter(facility -> facilityId.equals(facility.getFacilityId()))
                .findFirst()
                .map(facility -> facility.getTotalRevenue())
                .orElse(BigDecimal.ZERO);
    }
}
