-- Repeatable migration: Flyway applies it whenever its content changes, regardless of the
-- version history of the target database (versioned migrations whose numbers collide with an
-- older history are silently skipped, which is why this is not a V__ file).
--
-- Admin: manages accounts, roles and facility access, and monitors transactions read-only.
-- Facility/policy/price writes and revenue reports belong to the Business Operations Manager.
-- Idempotent.
UPDATE role_permissions rp
SET is_active = FALSE,
    updated_at = CURRENT_TIMESTAMP
FROM roles r, permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND r.name = 'ADMIN'
  AND p.name IN (
      'FACILITY_CREATE', 'FACILITY_UPDATE', 'FACILITY_DELETE',
      'POLICY_CREATE', 'POLICY_UPDATE', 'POLICY_DELETE',
      'UNIT_TYPE_UPDATE',
      'REPORT_VIEW'
  );

INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'ADMIN read-only transaction monitoring'
FROM roles r, permissions p
WHERE r.name = 'ADMIN' AND p.name = 'PAYMENT_VIEW'
ON CONFLICT (role_id, permission_id)
DO UPDATE SET is_active = TRUE, updated_at = CURRENT_TIMESTAMP;
