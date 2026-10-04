ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS overdue_detected_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS overdue_fee_accrued NUMERIC(12,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS access_disabled_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS sealing_pending_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS sealing_approved_at TIMESTAMP;

ALTER TABLE payments
    ADD COLUMN IF NOT EXISTS note VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_bookings_active_end_date
    ON bookings(status, end_date);

CREATE INDEX IF NOT EXISTS idx_payments_booking_type_status_note
    ON payments(booking_id, payment_type, status, note);