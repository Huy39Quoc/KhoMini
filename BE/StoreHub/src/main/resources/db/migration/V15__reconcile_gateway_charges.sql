ALTER TABLE payments ADD COLUMN last_gateway_query_at TIMESTAMP;
CREATE INDEX idx_payments_charge_reconciliation
    ON payments(status, payment_time, last_gateway_query_at)
    WHERE gateway_create_date IS NOT NULL;

-- A booking can have several gateway attempts. Each captured attempt needs its
-- own refund if its booking was already cancelled or another attempt succeeded.
ALTER TABLE refund_requests DROP CONSTRAINT refund_requests_booking_id_key;
CREATE INDEX idx_refund_requests_booking ON refund_requests(booking_id);
CREATE UNIQUE INDEX ux_refund_requests_original_payment ON refund_requests(original_payment_id);
