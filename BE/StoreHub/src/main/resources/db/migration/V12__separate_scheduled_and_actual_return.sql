-- The old return_time column stored either the customer's appointment or the
-- actual handover time. Keep actual returns in return_time going forward.
-- Idempotent: dữ liệu chỉ được chuyển khi cột scheduled_return_time vừa được thêm mới.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'bookings' AND column_name = 'scheduled_return_time') THEN
        ALTER TABLE bookings ADD COLUMN scheduled_return_time TIMESTAMP;

        UPDATE bookings
        SET scheduled_return_time = return_time,
            return_time = NULL
        WHERE status = 'ACTIVE' AND return_time IS NOT NULL;
    END IF;
END $$;
