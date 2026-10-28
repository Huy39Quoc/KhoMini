"""Exercise the actual reporting SQL and compatibility view on isolated fixtures.

Uses SQLite's portable SQL subset, not a live PostgreSQL database.
"""
import pathlib
import re
import sqlite3
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
REPOSITORY = ROOT / "src/main/java/com/storehub/repository/DepositDeductionRepository.java"
MIGRATION = ROOT / "src/main/resources/db/migration/V5__deposit_deduction_ledger.sql"


class DepositSqlTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.row_factory = sqlite3.Row
        self.db.executescript("""
            CREATE TABLE facilities(id TEXT PRIMARY KEY, name TEXT);
            CREATE TABLE storage_units(id TEXT PRIMARY KEY, facility_id TEXT);
            CREATE TABLE bookings(id TEXT PRIMARY KEY, storage_unit_id TEXT, status TEXT, deposit_paid NUMERIC);
            CREATE TABLE payments(id TEXT PRIMARY KEY, booking_id TEXT, amount NUMERIC,
                payment_type TEXT, status TEXT, transaction_id TEXT, payment_time TEXT);
            CREATE TABLE refund_requests(id TEXT PRIMARY KEY, booking_id TEXT, deposit_amount NUMERIC,
                damage_deduction NUMERIC, created_at TEXT, completed_at TEXT, status TEXT);
            CREATE TABLE handover_records(id TEXT PRIMARY KEY, booking_id TEXT, damage_fee NUMERIC,
                recorded_at TEXT, record_type TEXT);
            INSERT INTO facilities VALUES ('f','Facility');
            INSERT INTO storage_units VALUES ('u','f');
        """)
        self.db.executescript(MIGRATION.read_text(encoding="utf-8"))
        amounts = {"new-partial": 1000, "new-full": 500, "old-full": 300, "old-partial": 400, "cancel": 200}
        for booking, amount in amounts.items():
            self.db.execute("INSERT INTO bookings VALUES (?, 'u', ?, ?)",
                            (booking, "CANCELLED" if booking == "cancel" else "COMPLETED", amount))
            self.db.execute("INSERT INTO payments VALUES (?, ?, ?, 'DEPOSIT','PAID',?, '2026-01-01 09:00:00')",
                            ("p-" + booking, booking, amount, "TX-" + booking))
        for booking, amount, day in [("new-partial", 200, 5), ("new-full", 500, 7),
                                     ("old-full", 300, 8), ("old-partial", 100, 10)]:
            self.db.execute("INSERT INTO handover_records VALUES (?, ?, ?, ?, 'RETURN')",
                            ("h-" + booking, booking, amount, f"2026-02-{day:02} 09:00:00"))
        for booking, amount, day, kind in [("new-partial", 200, 5, "DAMAGE"),
                                          ("new-full", 500, 7, "DAMAGE"), ("cancel", 200, 9, "CANCELLATION")]:
            self.db.execute("INSERT INTO deposit_deductions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                            ("d-" + booking, "2026-02-01", "2026-02-01", booking, "p-" + booking,
                             amount, kind, "Fixture", f"2026-02-{day:02} 09:00:00"))
        for booking, refunded, damage, day in [("new-partial", 800, 200, 5), ("old-partial", 300, 100, 10)]:
            self.db.execute("INSERT INTO refund_requests VALUES (?, ?, ?, ?, ?, ?, 'COMPLETED')",
                            ("r-" + booking, booking, refunded, damage,
                             f"2026-02-{day:02} 09:00:00", "2026-03-15 09:00:00"))
        # Refund mirror rows, failed charges and rent must not become new deposits.
        self.db.execute("INSERT INTO payments VALUES ('rf','new-partial',800,'DEPOSIT','REFUNDED','RF-1','2026-03-15')")
        self.db.execute("INSERT INTO payments VALUES ('failed','new-partial',900,'DEPOSIT','FAILED','FAIL-1','2026-01-01')")
        self.db.execute("INSERT INTO payments VALUES ('rent','new-partial',5000,'RENTAL_FEE','PAID','RENT-1','2026-01-01')")
        source = REPOSITORY.read_text(encoding="utf-8")
        self.query = re.search(r'@Query\(value = """\s*(WITH events AS .*?)\s*""", nativeQuery = true\)',
                               source, re.S).group(1)

    def tearDown(self):
        self.db.close()

    def period(self, month):
        return self.db.execute(self.query, {"fromDate": f"2026-{month:02}-01 00:00:00",
                                           "toDate": f"2026-{month:02}-31 23:59:59"}).fetchone()

    def test_receipts_are_not_reduced_before_deduction_date(self):
        row = self.period(1)
        self.assertEqual((0, 2400, 0, 0), tuple(row[k] for k in ["openingBalance", "received", "refunded", "retained"]))

    def test_partial_full_and_historical_deductions_are_not_double_counted(self):
        row = self.period(2)
        self.assertEqual((2400, 0, 0, 1300), tuple(row[k] for k in ["openingBalance", "received", "refunded", "retained"]))
        self.assertEqual(1100, row["damageRetained"])
        self.assertEqual(200, row["cancellationRetained"])
        self.assertEqual(1, self.db.execute("SELECT COUNT(*) FROM deposit_deduction_events WHERE booking_id='old-partial'").fetchone()[0])
        self.assertEqual(300, self.db.execute("SELECT amount FROM deposit_deduction_events WHERE booking_id='old-full'").fetchone()[0])

    def test_refunds_reduce_balance_only_in_completion_period(self):
        row = self.period(3)
        self.assertEqual((1100, 0, 1100, 0), tuple(row[k] for k in ["openingBalance", "received", "refunded", "retained"]))

    def test_rejected_refund_stays_held(self):
        self.db.execute("UPDATE refund_requests SET status='REJECTED', completed_at=NULL WHERE id='r-new-partial'")
        row = self.period(3)
        self.assertEqual(300, row["refunded"])
        self.assertEqual(800, row["openingBalance"] + row["received"] - row["refunded"] - row["retained"])

    def test_schema_and_report_never_rewrite_historical_booking_balance(self):
        self.period(2)
        self.assertEqual(300, self.db.execute("SELECT deposit_paid FROM bookings WHERE id='old-full'").fetchone()[0])

    def test_same_original_payment_cannot_be_converted_twice(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO deposit_deductions SELECT 'duplicate',created_at,updated_at,booking_id,original_payment_id,amount,deduction_type,reason,recorded_at FROM deposit_deductions WHERE id='d-new-full'")


if __name__ == "__main__":
    unittest.main()
