ALTER TABLE payments ADD COLUMN voided_at TIMESTAMP;

-- Conservatively prevent previously failed extensions from activating a later
-- extension request when a delayed success callback arrives after deployment.
UPDATE payments SET voided_at = CURRENT_TIMESTAMP
WHERE payment_type = 'EXTRA_CHARGE' AND note = 'RENTAL_EXTENSION' AND status = 'FAILED';
