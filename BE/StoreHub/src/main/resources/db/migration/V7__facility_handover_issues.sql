ALTER TABLE bookings
    ADD COLUMN handover_issue_status varchar(20),
    ADD COLUMN handover_issue_reported_at timestamp,
    ADD COLUMN handover_issue_reason text,
    ADD COLUMN handover_issue_due_at timestamp,
    ADD COLUMN handover_issue_customer_agreed_at timestamp,
    ADD COLUMN handover_issue_resolved_by uuid,
    ADD COLUMN handover_issue_resolution_note text;

-- Protect existing rejected handovers too. Give managers a fresh resolution
-- window on upgrade instead of treating old facility failures as customer no-shows.
UPDATE bookings b SET
    handover_issue_status = 'OPEN',
    handover_issue_reported_at = h.recorded_at,
    handover_issue_reason = COALESCE(NULLIF(h.notes, ''), 'Không thể bàn giao ngăn kho'),
    handover_issue_due_at = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh') + interval '48 hours'
FROM (
    SELECT DISTINCT ON (booking_id) booking_id, recorded_at, notes
    FROM handover_records WHERE record_type = 'CHECK_IN_REJECTED'
    ORDER BY booking_id, recorded_at DESC, id DESC
) h
WHERE b.id = h.booking_id AND b.status = 'CONFIRMED'
    AND b.handover_time IS NULL AND b.handed_over_by_staff_id IS NULL;

ALTER TABLE bookings ADD CONSTRAINT ck_handover_issue_status CHECK (
    handover_issue_status IS NULL OR handover_issue_status IN ('OPEN', 'ARRANGED', 'RESOLVED', 'CANCELLED'));
CREATE INDEX idx_booking_handover_issue_due ON bookings(handover_issue_due_at)
    WHERE status = 'CONFIRMED' AND handover_issue_status IN ('OPEN', 'ARRANGED');
