-- Existing requests retain a deadline based on the policy currently attached
-- to their facility; newly created requests snapshot the policy in application code.
-- Idempotent: việc tính hạn theo policy chỉ chạy khi cột due_at vừa được thêm mới.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'refund_requests' AND column_name = 'due_at') THEN
        ALTER TABLE refund_requests ADD COLUMN due_at TIMESTAMP;

        UPDATE refund_requests r
        SET due_at = r.created_at +
            COALESCE(p.deposit_refund_sla_days, 5) * INTERVAL '1 day'
        FROM bookings b
        JOIN storage_units su ON su.id = b.storage_unit_id
        LEFT JOIN facility_policies p ON p.facility_id = su.facility_id
        WHERE r.booking_id = b.id;
    END IF;
END $$;

UPDATE refund_requests SET due_at = created_at + INTERVAL '5 days'
WHERE due_at IS NULL;

ALTER TABLE refund_requests ALTER COLUMN due_at SET NOT NULL;
