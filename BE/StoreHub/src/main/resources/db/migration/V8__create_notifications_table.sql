-- =========================================================
-- NOTIFICATIONS TABLE
-- =========================================================

CREATE TABLE IF NOT EXISTS notifications
(
    id              UUID                        NOT NULL,
    created_at      TIMESTAMP                   NOT NULL,
    updated_at      TIMESTAMP                   NOT NULL,
    recipient_id    UUID                        NOT NULL,
    title           VARCHAR(255)                NOT NULL,
    content         TEXT                        NOT NULL,
    type            VARCHAR(50)                 NOT NULL,
    reference_id    UUID,
    reference_type  VARCHAR(50),
    facility_id     UUID,
    is_read         BOOLEAN                     NOT NULL DEFAULT FALSE,
    read_at         TIMESTAMP,

    CONSTRAINT pk_notifications PRIMARY KEY (id),
    CONSTRAINT fk_notifications_recipient FOREIGN KEY (recipient_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_notifications_facility FOREIGN KEY (facility_id) REFERENCES facilities (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications (recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread ON notifications (recipient_id, is_read, created_at DESC);
