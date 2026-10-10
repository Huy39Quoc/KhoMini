package com.storehub.integration;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.storehub.service.EmailService;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.ContextConfiguration;

import java.time.LocalDate;
import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
    @MockBean EmailService emailService;

    @BeforeEach
    void ensureDisposableDatabase() {
        String database = jdbc.queryForObject("select current_database()", String.class);
        assertTrue(database != null && database.startsWith("storehub_it_"),
                "Integration test writes data. Use a disposable DB named storehub_it_*.");
    }

    @Test
    void migrationsAuthReservationPaymentAttemptAndCancellation() throws Exception {
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from flyway_schema_history where version = '18' and success = true",
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

        String booked = mvc.perform(post("/api/v1/bookings")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of(
                        "facilityId", available.get("facility_id"),
                        "unitTypeId", available.get("unit_type_id"),
                        "startDate", LocalDate.now().plusDays(2).toString(),
                        "rentalMonths", 1))))
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
    }
}
