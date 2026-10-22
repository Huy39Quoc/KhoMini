-- Policy edits apply immediately to future bookings. Old bookings cannot be
-- reconstructed historically: explicitly mark their migration-time baseline.
ALTER TABLE facility_policies ADD COLUMN cancellation_policy_effective_at timestamp;
UPDATE facility_policies SET cancellation_policy_effective_at = COALESCE(updated_at, created_at, LOCALTIMESTAMP);

ALTER TABLE bookings
    ADD COLUMN cancellation_full_refund_hours integer,
    ADD COLUMN cancellation_partial_refund_hours integer,
    ADD COLUMN cancellation_partial_refund_percent double precision,
    ADD COLUMN cancellation_policy_effective_at timestamp,
    ADD COLUMN cancellation_policy_captured_at timestamp,
    ADD COLUMN cancellation_policy_legacy boolean;

UPDATE bookings b SET
    cancellation_full_refund_hours = p.cancellation_full_refund_hours,
    cancellation_partial_refund_hours = p.cancellation_partial_refund_hours,
    cancellation_partial_refund_percent = p.cancellation_partial_refund_percent,
    cancellation_policy_effective_at = p.cancellation_policy_effective_at,
    cancellation_policy_captured_at = LOCALTIMESTAMP,
    cancellation_policy_legacy = true
FROM storage_units u JOIN facility_policies p ON p.facility_id = u.facility_id
WHERE b.storage_unit_id = u.id;

-- Preserve the existing full-refund behavior for facilities without a policy,
-- even for cancellations after the scheduled start.
UPDATE bookings SET
    cancellation_full_refund_hours = -2147483648,
    cancellation_partial_refund_hours = -2147483648,
    cancellation_partial_refund_percent = 100,
    cancellation_policy_effective_at = LOCALTIMESTAMP,
    cancellation_policy_captured_at = LOCALTIMESTAMP,
    cancellation_policy_legacy = true
WHERE cancellation_policy_captured_at IS NULL;

ALTER TABLE bookings
    ALTER COLUMN cancellation_full_refund_hours SET NOT NULL,
    ALTER COLUMN cancellation_partial_refund_hours SET NOT NULL,
    ALTER COLUMN cancellation_partial_refund_percent SET NOT NULL,
    ALTER COLUMN cancellation_policy_captured_at SET NOT NULL,
    ALTER COLUMN cancellation_policy_legacy SET NOT NULL;
