-- Dọn các dòng waitlists trỏ tới user / cơ sở / loại kho không còn tồn tại.
-- Chạy trước khi Hibernate tạo khóa ngoại, tránh lỗi "violates foreign key constraint" lúc khởi động
-- trên CSDL cũ (tạo từ bản trước khi có khóa ngoại). An toàn khi chạy lại và trên CSDL mới.
DO $$
BEGIN
    IF to_regclass('public.waitlists') IS NOT NULL THEN
        DELETE FROM waitlists
        WHERE customer_id NOT IN (SELECT id FROM users)
           OR facility_id NOT IN (SELECT id FROM facilities)
           OR unit_type_id NOT IN (SELECT id FROM unit_types);
    END IF;
END
$$;
