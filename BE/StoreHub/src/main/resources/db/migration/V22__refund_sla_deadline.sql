ALTER TABLE refund_requests ADD COLUMN due_at TIMESTAMP;

-- Existing requests retain a deadline based on the policy currently attached
-- to their facility; newly created requests snapshot the policy in application code.
UPDATE refund_requests r
SET due_at = r.created_at +
    COALESCE(p.deposit_refund_sla_days, 5) * INTERVAL '1 day'
FROM bookings b
JOIN storage_units su ON su.id = b.storage_unit_id
LEFT JOIN facility_policies p ON p.facility_id = su.facility_id
WHERE r.booking_id = b.id;

UPDATE refund_requests SET due_at = created_at + INTERVAL '5 days'
WHERE due_at IS NULL;

ALTER TABLE refund_requests ALTER COLUMN due_at SET NOT NULL;
