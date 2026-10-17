-- Idempotent: chỉ khởi tạo danh sách ảnh khi cột images vừa được thêm mới,
-- tránh ghi đè danh sách ảnh đã chỉnh sửa.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'facilities' AND column_name = 'images') THEN
        ALTER TABLE facilities ADD COLUMN images TEXT;

        -- Khởi tạo danh sách ảnh từ ảnh hiện tại nếu có
        UPDATE facilities
        SET images = image_url
        WHERE image_url IS NOT NULL;
    END IF;
END $$;
