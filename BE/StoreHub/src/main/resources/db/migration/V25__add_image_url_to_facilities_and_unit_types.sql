ALTER TABLE facilities ADD COLUMN IF NOT EXISTS image_url VARCHAR(500);
ALTER TABLE unit_types ADD COLUMN IF NOT EXISTS image_url VARCHAR(500);

-- Gán hình ảnh kho lưu trữ mẫu cho các cơ sở và loại kho hiện tại
UPDATE facilities
SET image_url = 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80'
WHERE image_url IS NULL;

UPDATE unit_types
SET image_url = 'https://images.unsplash.com/photo-1590402494682-cd3fb53b1f70?auto=format&fit=crop&w=800&q=80'
WHERE image_url IS NULL;
