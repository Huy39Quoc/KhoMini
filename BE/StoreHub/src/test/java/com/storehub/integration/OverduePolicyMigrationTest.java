package com.storehub.integration;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.ScriptUtils;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/** Exercises V6 against pre-upgrade records in an isolated PostgreSQL schema. */
@EnabledIfEnvironmentVariable(named = "STOREHUB_INTEGRATION_TEST", matches = "true")
class OverduePolicyMigrationTest {
    @Test
    void backfillsExistingContractsWithoutChangingDebtAndFreezesLaterPolicyEdits() throws Exception {
        try (Connection connection = connect()) {
            connection.setAutoCommit(false);
            try {
                prepare(connection, true);
                ScriptUtils.executeSqlScript(connection, new ClassPathResource(
                        "db/migration/V6__booking_overdue_policy_snapshot.sql"));
                execute(connection, "UPDATE facility_policies SET daily_late_fee = 100000, overdue_grace_days = 0");
                try (var statement = connection.createStatement();
                     var rows = statement.executeQuery("SELECT * FROM bookings")) {
                    assertTrue(rows.next());
                    assertEquals(0, rows.getBigDecimal("overdue_daily_late_fee").compareTo(
                            new java.math.BigDecimal("50000")));
                    assertEquals(1, rows.getInt("overdue_grace_days"));
                    assertEquals(3, rows.getInt("overdue_access_disable_days"));
                    assertEquals(7, rows.getInt("overdue_sealing_days"));
                    assertTrue(rows.getBoolean("overdue_policy_legacy"));
                    assertNotNull(rows.getTimestamp("overdue_policy_captured_at"));
                    assertEquals(0, rows.getBigDecimal("overdue_fee_accrued").compareTo(
                            new java.math.BigDecimal("100000")));
                }
                try (var statement = connection.createStatement();
                     var rows = statement.executeQuery("SELECT amount FROM payments")) {
                    assertTrue(rows.next());
                    assertEquals(0, rows.getBigDecimal(1).compareTo(new java.math.BigDecimal("100000")));
                }
                var savepoint = connection.setSavepoint();
                assertThrows(SQLException.class, () -> execute(connection,
                        "UPDATE bookings SET overdue_daily_late_fee = -1"));
                connection.rollback(savepoint);
            } finally {
                connection.rollback(); // Includes the private schema and every test record.
            }
        }
    }

    @Test
    void missingLegacyPolicyStopsMigrationInsteadOfInventingContractTerms() throws Exception {
        try (Connection connection = connect()) {
            connection.setAutoCommit(false);
            try {
                prepare(connection, false);
                assertThrows(org.springframework.jdbc.datasource.init.ScriptException.class,
                        () -> ScriptUtils.executeSqlScript(connection, new ClassPathResource(
                                "db/migration/V6__booking_overdue_policy_snapshot.sql")));
            } finally {
                connection.rollback();
            }
        }
    }

    private Connection connect() throws SQLException {
        Connection connection = DriverManager.getConnection(System.getenv("DB_URL"),
                System.getenv("DB_USERNAME"), System.getenv("DB_PASSWORD"));
        try (var statement = connection.createStatement();
             var rows = statement.executeQuery("SELECT current_database()")) {
            rows.next();
            if (!rows.getString(1).startsWith("storehub_it_")) {
                connection.close();
                throw new IllegalStateException("Use a disposable database named storehub_it_*");
            }
        }
        return connection;
    }

    private void prepare(Connection connection, boolean withPolicy) throws SQLException {
        String schema = "overdue_snapshot_" + UUID.randomUUID().toString().replace("-", "");
        execute(connection, "CREATE SCHEMA " + schema);
        connection.setSchema(schema);
        execute(connection, "CREATE TABLE facility_policies (facility_id integer, daily_late_fee numeric(12,2), "
                + "overdue_grace_days integer, overdue_access_disable_days integer, overdue_sealing_days integer)");
        execute(connection, "CREATE TABLE storage_units (id integer, facility_id integer)");
        execute(connection, "CREATE TABLE bookings (storage_unit_id integer, overdue_fee_accrued numeric(12,2))");
        execute(connection, "CREATE TABLE payments (amount numeric(12,2))");
        execute(connection, "INSERT INTO storage_units VALUES (10, 20)");
        execute(connection, "INSERT INTO bookings VALUES (10, 100000)");
        execute(connection, "INSERT INTO payments VALUES (100000)");
        if (withPolicy) execute(connection, "INSERT INTO facility_policies VALUES (20, 50000, 1, 3, 7)");
    }

    private void execute(Connection connection, String sql) throws SQLException {
        try (var statement = connection.createStatement()) {
            statement.execute(sql);
        }
    }
}
