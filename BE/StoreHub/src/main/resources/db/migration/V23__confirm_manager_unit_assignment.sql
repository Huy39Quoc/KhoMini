-- Grandfather already confirmed/active contracts so migration does not block
-- scheduled handovers. Pending payments must go through manager confirmation
-- if they succeed after this upgrade.
-- Idempotent: chỉ áp dụng khi cột vừa được thêm mới.
-- New bookings explicitly start with false until the manager confirms the
-- provisional hold or swaps it for another available unit.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'bookings' AND column_name = 'unit_assignment_confirmed') THEN
        ALTER TABLE bookings ADD COLUMN unit_assignment_confirmed BOOLEAN NOT NULL DEFAULT FALSE;

        UPDATE bookings SET unit_assignment_confirmed = TRUE
        WHERE status IN ('CONFIRMED', 'ACTIVE', 'COMPLETED');
    END IF;
END $$;
