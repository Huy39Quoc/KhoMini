-- The old return_time column stored either the customer's appointment or the
-- actual handover time. Keep actual returns in return_time going forward.
ALTER TABLE bookings ADD COLUMN scheduled_return_time TIMESTAMP;

UPDATE bookings
SET scheduled_return_time = return_time,
    return_time = NULL
WHERE status = 'ACTIVE' AND return_time IS NOT NULL;
