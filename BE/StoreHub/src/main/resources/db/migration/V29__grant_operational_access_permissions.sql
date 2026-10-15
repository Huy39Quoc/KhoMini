-- These existing self-service and front-desk flows need the matching action permissions.
-- Booking ownership and facility assignment are checked by the service layer.
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Operational access permission'
FROM roles r, permissions p
WHERE (r.name = 'STAFF' AND p.name = 'ACCESS_CREDENTIAL_UPDATE')
   OR (r.name = 'CUSTOMER' AND p.name IN ('ACCESS_CREDENTIAL_UPDATE', 'CONTRACT_UPDATE'))
ON CONFLICT (role_id, permission_id) DO NOTHING;
