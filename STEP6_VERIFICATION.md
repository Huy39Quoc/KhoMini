# Bước 6 — kiểm thử tích hợp và cấu hình môi trường

Mã này cung cấp kiểm thử DB thật và chặn cấu hình thanh toán sandbox khi chạy
Spring profile `prod`. Kết quả VNPay chỉ được xác nhận sau khi kiểm tra giao dịch
trên sandbox/merchant portal, không thể thay thế bằng unit test hoặc response tự tạo.

## G2: chạy suite BE trên PostgreSQL riêng

Tạo một database PostgreSQL **trống, dùng riêng cho test**, tên bắt đầu bằng
`storehub_it_`. Bài test `ReservationDatabaseFlowTest` từ chối chạy với DB tên
khác. Có thể dùng Docker trên máy cá nhân:

```powershell
docker run --name storehub-it-db -e POSTGRES_DB=storehub_it_local -e POSTGRES_PASSWORD=local-only-test -p 5433:5432 -d postgres:16
```

Mở PowerShell ở `BE\StoreHub`; thiết lập biến môi trường trong phiên này. Đặt
`VNPAY_TMN_CODE` và `VNPAY_HASH_SECRET` theo **tài khoản sandbox riêng của nhóm**.
Không commit giá trị thật, `.env`, hay URL thanh toán có chữ ký.

```powershell
$env:DB_URL = "jdbc:postgresql://localhost:5433/storehub_it_local"
$env:DB_USERNAME = "postgres"
$env:DB_PASSWORD = "local-only-test"
$env:MAIL_USERNAME = "unused@example.invalid"
$env:MAIL_PASSWORD = "unused"
$env:APP_FRONTEND_URL = "http://localhost:3000"
$env:JWT_SECRET = "integration-test-only-secret-longer-than-32-bytes"
$env:JWT_ACCESS_TOKEN_EXPIRATION = "900000"
$env:JWT_REFRESH_TOKEN_EXPIRATION = "604800000"
$env:SEED_ADMIN_PASSWORD = "local-admin-test"
$env:SEED_FACILITY_MANAGER_PASSWORD = "local-manager-test"
$env:SEED_BUSINESS_MANAGER_PASSWORD = "local-business-test"
$env:SEED_STAFF_PASSWORD = "local-staff-test"
$env:SEED_CUSTOMER_PASSWORD = "local-customer-test"
$env:VNPAY_TMN_CODE = Read-Host "VNPay sandbox TMN code"
$env:VNPAY_HASH_SECRET = Read-Host "VNPay sandbox hash secret"
$env:STOREHUB_INTEGRATION_TEST = "true"
$env:SPRING_FLYWAY_VALIDATE_ON_MIGRATE = "true"
.\mvnw.cmd test
```

Test xác nhận Flyway V18 thành công; HTTP đăng ký, đăng nhập JWT, catalog,
đặt chỗ, khởi tạo một payment attempt, hủy đơn, trả unit về `AVAILABLE`, IPN
đến muộn có chữ ký và gửi trùng: booking không sống lại, chỉ có một yêu cầu
hoàn đủ khoản đã thu trên PostgreSQL. IPN này là giả lập trong test, **không**
chứng minh VNPay sandbox đã xử lý giao dịch. Email được mock. Các test còn lại trong
suite kiểm tra callback, IPN muộn, refund và phân công. Nếu Docker chưa sẵn
sàng, tạo DB rỗng có cùng tiền tố trong PostgreSQL của bạn rồi đổi `DB_URL`.

Trong `FE\storehub_mobile`:

```powershell
flutter analyze
flutter test
```

Chạy trên Android emulator với `flutter run`. Với thiết bị thật, dùng URL HTTPS
của BE thay cho `10.0.2.2` và kiểm tra lại các vai trò: customer, staff,
facility manager, business manager, admin. Đặc biệt thử đăng nhập lại sau khi
đóng ứng dụng, booking đang chờ, trang 2 của danh sách, nhận/trả kho và ticket.

## G1: kịch bản VNPay sandbox cần kiểm chứng thủ công

Cấu hình `VNPAY_RETURN_URL` thành địa chỉ **HTTPS public** của BE, kết thúc bằng
`/api/v1/payments/vnpay-return`; cấu hình IPN trong merchant portal là
`https://<host>/api/v1/payments/vnpay-ipn`. Địa chỉ `10.0.2.2` chỉ dùng để
emulator gọi BE; VNPay không thể gửi IPN tới đó. Dùng `VNPAY_MERCHANT_IP`
của máy chủ BE và cấu hình đúng `VNPAY_TRANSACTION_URL` cho sandbox.

| Ca kiểm tra | Đối chiếu bắt buộc |
| --- | --- |
| Thanh toán thành công | VNPay ghi giao dịch; cả DEPOSIT và RENTAL_FEE = PAID, booking = CONFIRMED. |
| Khách hủy/thanh toán thất bại | Booking không được xác nhận; không có khoản PAID không được đối soát. |
| Hủy/hết hạn trước khi IPN thành công đến | Booking không sống lại; giao dịch đã thu phải vào quy trình hoàn/đối soát. |
| Trả kho, hoàn cọc toàn phần | `refund_requests` = COMPLETED chỉ sau kết quả có chữ ký và đối chiếu portal. |
| Hủy theo chính sách, hoàn một phần | Số tiền, loại hoàn và giao dịch gốc khớp portal; không gửi trùng request. |
| Mất phản hồi hoặc lỗi mạng lúc hoàn | Trạng thái cần kiểm tra tiếp, dùng QueryDr/portal trước khi gửi lại. |

Ghi mã booking, transaction ID, refund request ID và kết quả portal (không ghi
secret hoặc thông tin thẻ) cho mỗi ca. Theo tài liệu VNPay, `vnp_ResponseCode`
cho biết kết quả xử lý yêu cầu QueryDr; phải đọc thêm `vnp_TransactionStatus`
để xác nhận trạng thái giao dịch:
https://sandbox.vnpayment.vn/apis/docs/truy-van-hoan-tien/querydr&refund.html

## G3: build thật

Backend: đặt `SPRING_PROFILES_ACTIVE=prod`, `DB_*`, `MAIL_*`, `JWT_*`,
`APP_FRONTEND_URL`, `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`, `VNPAY_URL`,
`VNPAY_TRANSACTION_URL`, `VNPAY_RETURN_URL`, `VNPAY_MERCHANT_IP`. Profile
`prod` yêu cầu HTTPS public, chặn URL sandbox/emulator, bật Flyway validation,
tắt Swagger và không tự tạo tài khoản demo. Cần cơ chế tạo tài khoản quản trị
ban đầu có kiểm soát trước khi sử dụng DB production.

Mobile release: `API_BASE_URL` phải là HTTPS public kết thúc bằng `/api/v1`.
Manifest release không bật cleartext. Thẻ test chỉ hiện ở debug, hoặc khi build
bản thử nghiệm với `--dart-define=VNPAY_SANDBOX=true`.

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Thay domain ví dụ bằng domain đang chạy thật. Trước khi chốt G3, kiểm tra
email reset mật khẩu dùng `APP_FRONTEND_URL` dẫn tới màn hình hoạt động, SSL
của API và VNPay hợp lệ trên thiết bị, IPN public nhận được, và đối chiếu số
liệu thanh toán/hoàn với portal. Không đưa bản build thử sandbox cho khách thật.
