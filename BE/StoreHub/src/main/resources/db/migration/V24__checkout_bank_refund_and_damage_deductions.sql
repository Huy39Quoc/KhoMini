ALTER TABLE bookings ADD COLUMN refund_bank_code VARCHAR(50);
ALTER TABLE bookings ADD COLUMN refund_account_number VARCHAR(50);
ALTER TABLE bookings ADD COLUMN refund_account_name VARCHAR(100);

ALTER TABLE handover_records ADD COLUMN damage_fee NUMERIC(12, 2) DEFAULT 0;
ALTER TABLE handover_records ADD COLUMN damage_reason VARCHAR(255);

ALTER TABLE refund_requests ADD COLUMN damage_deduction NUMERIC(12, 2) DEFAULT 0;
ALTER TABLE refund_requests ADD COLUMN bank_code VARCHAR(50);
ALTER TABLE refund_requests ADD COLUMN bank_account_number VARCHAR(50);
ALTER TABLE refund_requests ADD COLUMN bank_account_name VARCHAR(100);
ALTER TABLE refund_requests ADD COLUMN transfer_reference VARCHAR(100);
