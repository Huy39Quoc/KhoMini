ALTER TABLE payments ADD COLUMN gateway_create_date VARCHAR(14);
ALTER TABLE payments ADD COLUMN gateway_transaction_no VARCHAR(20);
ALTER TABLE payments ADD COLUMN gateway_amount NUMERIC(12,2);

CREATE TABLE refund_requests (
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

CREATE INDEX idx_refund_requests_status ON refund_requests(status);
