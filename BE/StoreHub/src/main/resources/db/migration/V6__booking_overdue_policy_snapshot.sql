-- Historical policy versions do not exist. Freeze the migration-time policy for
-- old contracts and mark that provenance; do not rewrite any payment or debt.
ALTER TABLE bookings
    ADD COLUMN overdue_daily_late_fee numeric(12,2),
    ADD COLUMN overdue_grace_days integer,
    ADD COLUMN overdue_access_disable_days integer,
    ADD COLUMN overdue_sealing_days integer,
    ADD COLUMN overdue_policy_captured_at timestamp,
    ADD COLUMN overdue_policy_legacy boolean;

UPDATE bookings b SET
    overdue_daily_late_fee = p.daily_late_fee,
    overdue_grace_days = p.overdue_grace_days,
    overdue_access_disable_days = p.overdue_access_disable_days,
    overdue_sealing_days = p.overdue_sealing_days,
    overdue_policy_captured_at = LOCALTIMESTAMP,
    overdue_policy_legacy = true
FROM storage_units u JOIN facility_policies p ON p.facility_id = u.facility_id
WHERE b.storage_unit_id = u.id;

-- Fail rather than invent a free/default policy for contracts missing a policy.
-- Repair those records explicitly before retrying this transactional migration.
ALTER TABLE bookings
    ALTER COLUMN overdue_daily_late_fee SET NOT NULL,
    ALTER COLUMN overdue_grace_days SET NOT NULL,
    ALTER COLUMN overdue_access_disable_days SET NOT NULL,
    ALTER COLUMN overdue_sealing_days SET NOT NULL,
    ALTER COLUMN overdue_policy_captured_at SET NOT NULL,
    ALTER COLUMN overdue_policy_legacy SET NOT NULL,
    ADD CONSTRAINT ck_booking_overdue_policy_nonnegative CHECK (
        overdue_daily_late_fee >= 0 AND overdue_grace_days >= 0
        AND overdue_access_disable_days >= 0 AND overdue_sealing_days >= 0);
