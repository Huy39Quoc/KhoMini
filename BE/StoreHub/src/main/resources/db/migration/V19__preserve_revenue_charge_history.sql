-- Report refunds on the day they complete, without rewriting the original charge.
-- Idempotent: các câu UPDATE chỉ chạy khi cột completed_at vừa được thêm mới,
-- tránh cộng tiền hoàn vào payments lần thứ hai.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'refund_requests' AND column_name = 'completed_at') THEN
        ALTER TABLE refund_requests ADD COLUMN completed_at TIMESTAMP;

        -- Before this migration the last status update was the completion timestamp.
        UPDATE refund_requests
        SET completed_at = COALESCE(updated_status_at, created_at)
        WHERE status = 'COMPLETED';

        -- Earlier partial refunds reduced payments.amount in place. Restore the
        -- captured amounts once so old charge periods do not lose their history.
        -- Full refunds retained the original amount but changed status to REFUNDED.
        UPDATE payments deposit
        SET amount = deposit.amount + refund.deposit_amount
        FROM refund_requests refund
        WHERE refund.original_payment_id = deposit.id
          AND refund.status = 'COMPLETED'
          AND deposit.status = 'PAID'
          AND deposit.payment_type = 'DEPOSIT'
          AND refund.deposit_amount > 0;

        UPDATE payments rent
        SET amount = rent.amount + refund.rental_amount
        FROM refund_requests refund
        JOIN payments deposit ON deposit.id = refund.original_payment_id
        WHERE rent.transaction_id = deposit.transaction_id || '-R'
          AND refund.status = 'COMPLETED'
          AND deposit.payment_type = 'DEPOSIT'
          AND rent.payment_type = 'RENTAL_FEE'
          AND rent.status = 'PAID'
          AND refund.rental_amount > 0;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_refund_requests_completed_at
ON refund_requests(completed_at) WHERE status = 'COMPLETED';
