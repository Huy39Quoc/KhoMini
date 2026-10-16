-- Idempotent: chỉ đánh dấu voided_at khi cột vừa được thêm mới.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'payments' AND column_name = 'voided_at') THEN
        ALTER TABLE payments ADD COLUMN voided_at TIMESTAMP;

        -- Conservatively prevent previously failed extensions from activating a later
        -- extension request when a delayed success callback arrives after deployment.
        UPDATE payments SET voided_at = CURRENT_TIMESTAMP
        WHERE payment_type = 'EXTRA_CHARGE' AND note = 'RENTAL_EXTENSION' AND status = 'FAILED';
    END IF;
END $$;
