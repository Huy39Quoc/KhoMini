-- Existing pending bookings have no reliable original quote to reconstruct.
-- They retain the legacy calculation path; new bookings always write both values.
ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS quoted_deposit_amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS quoted_management_fee NUMERIC(12,2);
