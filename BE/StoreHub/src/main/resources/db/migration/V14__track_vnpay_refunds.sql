ALTER TABLE payments ADD COLUMN IF NOT EXISTS gateway_create_date VARCHAR(14);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS gateway_transaction_no VARCHAR(20);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS gateway_amount NUMERIC(12,2);

CREATE TABLE IF NOT EXISTS refund_requests (
    id UUID PRIMARY KEY,
    booking_id UUID NOT NULL UNIQUE REFERENCES bookings(id),
    original_payment_id UUID NOT NULL REFERENCES payments(id),
    refund_payment_id UUID NOT NULL UNIQUE REFERENCES payments(id),
    request_id VARCHAR(32) NOT NULL UNIQUE,
    amount NUMERIC(12,2) NOT NULL,
    deposit_amount NUMERIC(12,2) NOT NULL,
    rental_amount NUMERIC(12,2) NOT NULL,
    status VARCHAR(30) NOT NULL,
    gateway_response_code VARCHAR(10),
    gateway_transaction_status VARCHAR(10),
    updated_status_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Bảng có thể đã tồn tại từ DB cũ: bảo đảm các cột không bắt buộc vẫn có đủ.
ALTER TABLE refund_requests ADD COLUMN IF NOT EXISTS gateway_response_code VARCHAR(10);
ALTER TABLE refund_requests ADD COLUMN IF NOT EXISTS gateway_transaction_status VARCHAR(10);
ALTER TABLE refund_requests ADD COLUMN IF NOT EXISTS updated_status_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_refund_requests_status ON refund_requests(status);
