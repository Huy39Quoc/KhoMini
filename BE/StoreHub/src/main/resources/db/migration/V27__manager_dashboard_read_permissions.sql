-- The operations dashboard reads a user summary and the role/permission counts.
-- These endpoints now check both role and authority, so existing business
-- manager accounts need the matching view grants after upgrading.
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Dashboard read access'
FROM roles r CROSS JOIN permissions p
WHERE r.name = 'BUSINESS_MANAGER'
  AND p.name IN ('USER_VIEW', 'ROLE_VIEW', 'PERMISSION_VIEW', 'ROLE_PERMISSION_VIEW')
ON CONFLICT (role_id, permission_id) DO NOTHING;

INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'Read role configuration'
FROM roles r CROSS JOIN permissions p
WHERE r.name = 'FACILITY_MANAGER'
  AND p.name IN ('ROLE_VIEW', 'PERMISSION_VIEW', 'ROLE_PERMISSION_VIEW')
ON CONFLICT (role_id, permission_id) DO NOTHING;
