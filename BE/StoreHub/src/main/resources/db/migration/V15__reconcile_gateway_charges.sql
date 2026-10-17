ALTER TABLE payments ADD COLUMN IF NOT EXISTS last_gateway_query_at TIMESTAMP;
CREATE INDEX IF NOT EXISTS idx_payments_charge_reconciliation
    ON payments(status, payment_time, last_gateway_query_at)
    WHERE gateway_create_date IS NOT NULL;

-- A booking can have several gateway attempts. Each captured attempt needs its
-- own refund if its booking was already cancelled or another attempt succeeded.
-- Xóa mọi unique constraint chỉ gồm cột booking_id, kể cả khi DB cũ đặt tên khác
-- (Hibernate) hoặc constraint đã được xóa từ trước.
DO $$
DECLARE
    c RECORD;
BEGIN
    FOR c IN
        SELECT con.conname
        FROM pg_constraint con
        WHERE con.conrelid = 'refund_requests'::regclass
          AND con.contype = 'u'
          AND ARRAY(
                SELECT a.attname::text
                FROM unnest(con.conkey) AS k(attnum)
                JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.attnum
              ) = ARRAY['booking_id']
    LOOP
        EXECUTE format('ALTER TABLE refund_requests DROP CONSTRAINT %I', c.conname);
    END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_refund_requests_booking ON refund_requests(booking_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_refund_requests_original_payment ON refund_requests(original_payment_id);
