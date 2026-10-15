-- Thêm các cột chính sách đặt trước và cam kết pháp lý cho cơ sở
ALTER TABLE facility_policies ADD COLUMN IF NOT EXISTS max_advance_reservation_days INTEGER DEFAULT 14;
ALTER TABLE facility_policies ADD COLUMN IF NOT EXISTS prohibited_items TEXT;
ALTER TABLE facility_policies ADD COLUMN IF NOT EXISTS terms_and_conditions TEXT;
ALTER TABLE facility_policies ADD COLUMN IF NOT EXISTS terms_version VARCHAR(30) DEFAULT 'v2026.1';

-- Cập nhật dữ liệu mặc định cho các chính sách cơ sở hiện tại
UPDATE facility_policies
SET prohibited_items = 'Chất dễ cháy nổ, bình gas, xăng dầu; Ma túy, chất kích thích, hóa chất độc hại; Động vật sống, thực phẩm tươi sống dễ thối rữa; Vũ khí, đạn dược, hàng cấm, pháo hoa; Hàng hóa có mùi nồng nặc gây ảnh hưởng kho xung quanh'
WHERE prohibited_items IS NULL OR prohibited_items = '';

UPDATE facility_policies
SET terms_and_conditions = E'1. Khách hàng cam kết tuân thủ quy chế vận hành và an toàn PCCC tại cơ sở lưu kho StoreHub.\n2. Tuyệt đối không lưu trữ hàng hóa thuộc danh mục cấm theo quy định của pháp luật và nội quy kho.\n3. Khách hàng chịu hoàn toàn trách nhiệm pháp lý và bồi thường nếu hàng hóa gây thiệt hại, cháy nổ hoặc vi phạm pháp luật.\n4. Thanh toán đúng hạn theo thỏa thuận thuê kho và phối hợp thực hiện bàn giao, kiểm tra kho khi có yêu cầu.'
WHERE terms_and_conditions IS NULL OR terms_and_conditions = '';

UPDATE facility_policies
SET terms_version = 'v2026.1'
WHERE terms_version IS NULL OR terms_version = '';

UPDATE facility_policies
SET max_advance_reservation_days = 14
WHERE max_advance_reservation_days IS NULL;

-- Thêm các trường lưu vết pháp lý cho bảng đơn đặt kho (bookings)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS prohibited_items_accepted BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS terms_accepted BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS terms_version VARCHAR(30);
