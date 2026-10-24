-- Schema only: do not change financial balances or fabricate historical events.
CREATE TABLE deposit_deductions (
    id UUID PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    booking_id UUID NOT NULL REFERENCES bookings(id),
    original_payment_id UUID NOT NULL UNIQUE REFERENCES payments(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    deduction_type VARCHAR(20) NOT NULL CHECK (deduction_type IN ('DAMAGE','CANCELLATION')),
    reason TEXT NOT NULL,
    recorded_at TIMESTAMP NOT NULL
);
CREATE INDEX idx_deposit_deductions_recorded_at ON deposit_deductions(recorded_at);
CREATE INDEX idx_deposit_deductions_booking ON deposit_deductions(booking_id);

-- Read-only compatibility with old partial and full damage deductions. Prefer
-- the new ledger; never count a refund's metadata and its inspection twice.
CREATE VIEW deposit_deduction_events AS
SELECT booking_id, amount, deduction_type, recorded_at FROM deposit_deductions
UNION ALL
SELECT r.booking_id, r.damage_deduction, 'DAMAGE', COALESCE((
    SELECT h.recorded_at FROM handover_records h
    WHERE h.booking_id = r.booking_id AND h.record_type = 'RETURN'
    ORDER BY h.recorded_at DESC, h.id DESC LIMIT 1
),r.created_at)
FROM refund_requests r
WHERE r.damage_deduction > 0
  AND NOT EXISTS (SELECT 1 FROM deposit_deductions d WHERE d.booking_id = r.booking_id AND d.deduction_type = 'DAMAGE')
UNION ALL
SELECT h.booking_id, h.damage_fee, 'DAMAGE', h.recorded_at
FROM handover_records h JOIN bookings b ON b.id = h.booking_id
WHERE b.status = 'COMPLETED' AND h.record_type = 'RETURN' AND h.damage_fee > 0
  AND h.id = (SELECT latest.id FROM handover_records latest
              WHERE latest.booking_id = h.booking_id AND latest.record_type = 'RETURN'
              ORDER BY latest.recorded_at DESC, latest.id DESC LIMIT 1)
  AND NOT EXISTS (SELECT 1 FROM refund_requests r WHERE r.booking_id = h.booking_id AND r.damage_deduction > 0)
  AND NOT EXISTS (SELECT 1 FROM deposit_deductions d WHERE d.booking_id = h.booking_id AND d.deduction_type = 'DAMAGE');
