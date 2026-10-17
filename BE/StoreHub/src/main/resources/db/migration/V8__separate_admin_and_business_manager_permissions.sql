-- System Administrator manages accounts, roles and facility-level access, and may
-- monitor transactions read-only. Creating/editing facilities, rental policies and
-- prices, and revenue reports belong to the Business Operations Manager, so Admin
-- no longer holds those write/report permissions.
-- Idempotent: re-running keeps the same rows deactivated.
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
