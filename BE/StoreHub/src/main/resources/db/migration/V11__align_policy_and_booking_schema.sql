-- V1, V5 and V7 have already run on some development databases.
-- Repeat their later schema changes here so existing data can be kept.

ALTER TABLE facility_policies
    ADD COLUMN IF NOT EXISTS management_fee_per_month NUMERIC(12,0) NOT NULL DEFAULT 50000,
    ADD COLUMN IF NOT EXISTS long_term_discount_min_months INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS long_term_discount_percent DOUBLE PRECISION NOT NULL DEFAULT 0;

ALTER TABLE bookings
    ALTER COLUMN access_pin TYPE VARCHAR(100),
    ADD COLUMN IF NOT EXISTS pin_failed_attempts INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS pin_locked_until TIMESTAMP,
    ADD COLUMN IF NOT EXISTS sealing_approved_at TIMESTAMP;
