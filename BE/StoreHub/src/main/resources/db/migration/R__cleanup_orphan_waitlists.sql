-- Dọn các dòng dữ liệu mồ côi (waitlists, gate_passes, refund_requests) không còn bảng cha.
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

    IF to_regclass('public.gate_passes') IS NOT NULL AND to_regclass('public.bookings') IS NOT NULL THEN
        DELETE FROM gate_passes
        WHERE booking_id NOT IN (SELECT id FROM bookings);
    END IF;

    IF to_regclass('public.refund_requests') IS NOT NULL THEN
        DELETE FROM refund_requests
        WHERE (to_regclass('public.bookings') IS NOT NULL AND booking_id NOT IN (SELECT id FROM bookings))
           OR (to_regclass('public.payments') IS NOT NULL AND original_payment_id IS NOT NULL AND original_payment_id NOT IN (SELECT id FROM payments))
           OR (to_regclass('public.payments') IS NOT NULL AND refund_payment_id IS NOT NULL AND refund_payment_id NOT IN (SELECT id FROM payments));
    END IF;
END
$$;

