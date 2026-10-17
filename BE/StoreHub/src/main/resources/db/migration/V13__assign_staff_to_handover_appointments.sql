ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS assigned_check_in_staff_id UUID REFERENCES users(id),
    ADD COLUMN IF NOT EXISTS assigned_check_out_staff_id UUID REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_bookings_check_in_staff ON bookings(assigned_check_in_staff_id);
CREATE INDEX IF NOT EXISTS idx_bookings_check_out_staff ON bookings(assigned_check_out_staff_id);
