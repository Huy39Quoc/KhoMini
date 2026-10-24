-- Existing agreements cannot be reconstructed from today's policy. Leave their
-- snapshots NULL rather than claiming customers accepted the current text.
ALTER TABLE bookings
    ADD COLUMN terms_content_snapshot TEXT,
    ADD COLUMN prohibited_items_snapshot TEXT,
    ADD COLUMN terms_hash VARCHAR(64);
