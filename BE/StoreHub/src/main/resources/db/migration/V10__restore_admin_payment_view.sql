-- The System Administrator monitors every transaction read-only. An earlier revision revoked
-- PAYMENT_VIEW from ADMIN; restore it (also creates the grant if it is missing).
-- Idempotent.
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'ADMIN read-only transaction monitoring'
FROM roles r, permissions p
WHERE r.name = 'ADMIN' AND p.name = 'PAYMENT_VIEW'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET is_active = TRUE, updated_at = CURRENT_TIMESTAMP;
