-- Idempotent: bỏ qua cơ sở đã tồn tại (DB cũ); chỉ cơ sở mới chèn mới được gán policy mặc định.
WITH new_facilities AS (
INSERT INTO facilities (
    id, name, code, address, city, contact_phone, email, status, open_time, close_time,
    air_conditioned_24h, image_url, images, created_at, updated_at
)
VALUES
    (
        gen_random_uuid(), 'StoreHub District 1', 'HCM-D1', '123 Nguyen Hue, Ben Nghe Ward', 'Ho Chi Minh City',
        '0901234567', 'storehubdistrict1@gmail.com', 'ACTIVE', '08:00:00', '20:00:00',
        TRUE, 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    ),
    (
        gen_random_uuid(), 'StoreHub District 7', 'HCM-D7', '456 Nguyen Huu Tho, Tan Hung Ward', 'Ho Chi Minh City',
        '0902345678', 'storehubdistrict7@gmail.com', 'ACTIVE', '08:00:00', '20:00:00',
        FALSE, 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    ),
    (
        gen_random_uuid(), 'StoreHub Thu Duc', 'HCM-TD', '789 Vo Van Ngan, Linh Chieu Ward', 'Ho Chi Minh City',
        '0903456789', 'storehubthuduc@gmail.com', 'ACTIVE', '08:00:00', '20:00:00',
        FALSE, 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=1200&q=80',
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    )
ON CONFLICT DO NOTHING
RETURNING id
)
INSERT INTO facility_policies (
    id, created_at, updated_at, facility_id, deposit_percentage,
    renewal_window_days,
    cancellation_full_refund_hours, cancellation_partial_refund_hours, cancellation_partial_refund_percent,
    return_notice_days, deposit_refund_sla_days,
    daily_late_fee, overdue_grace_days, overdue_access_disable_days, overdue_sealing_days,
    minimum_rental_months, max_advance_reservation_days,
    management_fee_per_month, long_term_discount_min_months, long_term_discount_percent,
    prohibited_items, terms_and_conditions, terms_version
)
SELECT
    gen_random_uuid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, id, 20.0,
    3,
    48, 24, 50.0,
    0, 5,
    50000.00, 1, 3, 7,
    1, 14,
    50000.00, 0, 0.0,
    'Chất dễ cháy nổ, bình gas, xăng dầu; Ma túy, chất kích thích, hóa chất độc hại; Động vật sống, thực phẩm tươi sống dễ thối rữa; Vũ khí, đạn dược, hàng cấm, pháo hoa; Hàng hóa có mùi nồng nặc gây ảnh hưởng kho xung quanh',
    E'1. Khách hàng cam kết tuân thủ quy chế vận hành và an toàn PCCC tại cơ sở lưu kho StoreHub.\n2. Tuyệt đối không lưu trữ hàng hóa thuộc danh mục cấm theo quy định của pháp luật và nội quy kho.\n3. Khách hàng chịu hoàn toàn trách nhiệm pháp lý và bồi thường nếu hàng hóa gây thiệt hại, cháy nổ hoặc vi phạm pháp luật.\n4. Thanh toán đúng hạn theo thỏa thuận thuê kho và phối hợp thực hiện bàn giao, kiểm tra kho khi có yêu cầu.',
    'v2026.1'
FROM new_facilities;