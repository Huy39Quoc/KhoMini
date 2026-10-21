-- Migration lặp lại (Flyway chạy lại mỗi khi nội dung file thay đổi); luôn idempotent.
-- Áp dụng cho cả CSDL mới lẫn CSDL đã tạo từ các bản migration cũ.
--
-- Quản trị hệ thống (ADMIN) chỉ giữ các quyền đúng vai trò:
--   * Tài khoản, vai trò, quyền, phân quyền (USER_*, ROLE_*, PERMISSION_*, ROLE_PERMISSION_*).
--   * Nhật ký hoạt động / lịch sử đăng nhập (ACTIVITY_LOG_VIEW, LOGIN_HISTORY_VIEW).
--   * Gán quản lý cho cơ sở (STAFF_ASSIGNMENT_CREATE) và xem danh mục cơ sở/chính sách (chỉ đọc).
--   * XEM lịch sử giao dịch toàn hệ thống (PAYMENT_VIEW, chỉ đọc).
-- Mọi nghiệp vụ vận hành (đặt kho, bàn giao, hoàn cọc, hỗ trợ khách, giá, chính sách,
-- báo cáo doanh thu...) thuộc các vai trò Khách hàng / Nhân viên / Quản lý cơ sở / Quản lý vận hành.

-- 1) Vô hiệu hóa mọi quyền ngoài danh sách được giữ.
UPDATE role_permissions rp
SET is_active = FALSE,
    updated_at = CURRENT_TIMESTAMP
FROM roles r, permissions p
WHERE rp.role_id = r.id
  AND rp.permission_id = p.id
  AND r.name = 'ADMIN'
  AND rp.is_active = TRUE
  AND NOT (
        p.name LIKE 'USER\_%'
     OR p.name LIKE 'ROLE\_%'
     OR p.name LIKE 'PERMISSION\_%'
     OR p.name IN ('ACTIVITY_LOG_VIEW', 'LOGIN_HISTORY_VIEW',
                   'STAFF_ASSIGNMENT_CREATE',
                   'FACILITY_VIEW', 'POLICY_VIEW',
                   'PAYMENT_VIEW')
  );

-- 2) Bảo đảm các quyền được giữ đang bật (kể cả quyền xem giao dịch bị thu hồi ở bản cũ).
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'ADMIN system administration (transactions: read-only)'
FROM roles r, permissions p
WHERE r.name = 'ADMIN'
  AND (
        p.name LIKE 'USER\_%'
     OR p.name LIKE 'ROLE\_%'
     OR p.name LIKE 'PERMISSION\_%'
     OR p.name IN ('ACTIVITY_LOG_VIEW', 'LOGIN_HISTORY_VIEW',
                   'STAFF_ASSIGNMENT_CREATE',
                   'FACILITY_VIEW', 'POLICY_VIEW',
                   'PAYMENT_VIEW')
  )
ON CONFLICT (role_id, permission_id)
DO UPDATE SET is_active = TRUE, updated_at = CURRENT_TIMESTAMP;

-- 3) Bảo đảm BUSINESS_MANAGER có quyền xem danh sách nhân sự / người dùng
INSERT INTO role_permissions (id, created_at, updated_at, role_id, permission_id, is_active, description)
SELECT gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
       r.id, p.id, TRUE, 'BUSINESS_MANAGER view users and staff assignments'
FROM roles r, permissions p
WHERE r.name = 'BUSINESS_MANAGER'
  AND p.name IN ('USER_VIEW', 'STAFF_ASSIGNMENT_VIEW')
ON CONFLICT (role_id, permission_id)
DO UPDATE SET is_active = TRUE, updated_at = CURRENT_TIMESTAMP;
