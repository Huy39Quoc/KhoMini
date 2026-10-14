ALTER TABLE facilities ADD COLUMN images TEXT;

-- Khởi tạo danh sách ảnh từ ảnh hiện tại nếu có
UPDATE facilities
SET images = image_url
WHERE image_url IS NOT NULL;
