-- 1. Add smart access columns to bookings table
ALTER TABLE bookings 
ADD COLUMN IF NOT EXISTS access_pin VARCHAR(10),
ADD COLUMN IF NOT EXISTS qr_access_token VARCHAR(255),
ADD COLUMN IF NOT EXISTS pin_updated_at TIMESTAMP;

-- 2. Create support tickets table (user_id is UUID, booking_id is BIGINT)
CREATE TABLE IF NOT EXISTS support_tickets (
    id BIGSERIAL PRIMARY KEY,
    ticket_code VARCHAR(50) NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES users(id),
    booking_id BIGINT REFERENCES bookings(id),
    category VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
    priority VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    assigned_staff_id UUID REFERENCES users(id),
    resolution_note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tickets_user_id ON support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_tickets_booking_id ON support_tickets(booking_id);