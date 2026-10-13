ALTER TABLE bookings ADD COLUMN unit_assignment_confirmed BOOLEAN NOT NULL DEFAULT FALSE;

-- Grandfather already confirmed/active contracts so migration does not block
-- scheduled handovers. Pending payments must go through manager confirmation
-- if they succeed after this upgrade.
UPDATE bookings SET unit_assignment_confirmed = TRUE
WHERE status IN ('CONFIRMED', 'ACTIVE', 'COMPLETED');

-- New bookings explicitly start with false until the manager confirms the
-- provisional hold or swaps it for another available unit.
