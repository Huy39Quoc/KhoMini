-- payments.note carries the charge purpose (OVERDUE_LATE_FEE, RENTAL_EXTENSION, ...).
-- The consolidated V1 omitted it; databases created before the consolidation already
-- have it, so this is a no-op there.
ALTER TABLE payments ADD COLUMN IF NOT EXISTS note VARCHAR(100);
