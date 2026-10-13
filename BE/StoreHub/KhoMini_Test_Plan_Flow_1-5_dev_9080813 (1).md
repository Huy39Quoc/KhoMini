# Kế hoạch kiểm thử KhoMini / StoreHub — Flow 1 đến Flow 5

**Mốc mã nguồn:** nhánh `dev`, commit `9080813` (`fix: accrue overdue fees before storage checkout`).  
**Phạm vi:** Backend Spring Boot (`BE/StoreHub`), ứng dụng Flutter (`FE/storehub_mobile`), PostgreSQL, email và VNPay sandbox.  
**Cách dùng:** chạy các mục theo thứ tự, đánh dấu `[x]` sau khi tự quan sát **kết quả mong đợi**. Tài liệu là kịch bản kiểm thử, không khẳng định các ca dưới đây đã chạy hoặc đã đạt.

## 1. Chuẩn bị môi trường và dữ liệu

### 1.1 Tài khoản, thiết bị, dữ liệu

| Thành phần | Chuẩn bị |
| --- | --- |
| Tài khoản | `CUSTOMER` (nên có khách A/B), `STAFF` (staff A/B), `FACILITY_MANAGER`, `BUSINESS_MANAGER`, `ADMIN`. DB mới ở môi trường dev có seed `admin@gmail.com`, `facility@gmail.com`, `business@gmail.com`, `staff@gmail.com`, `customer@gmail.com`; mật khẩu lấy từ biến `SEED_*_PASSWORD` đã tự đặt. Seed bỏ qua nếu DB đã có user. |
| Cơ sở | Ít nhất hai cơ sở A/B; một cơ sở hoạt động có manager, 2 staff, policy, 2 loại kho, ngăn trống; một cơ sở ngừng hoạt động. Một cơ sở hoặc loại có `máy lạnh 24/7`, một cái không. |
| Đơn và tiền | Booking chờ trả tiền, booking đã thanh toán/chờ bàn giao, booking đang thuê, booking quá hạn, một yêu cầu hoàn tiền. Với waitlist, chuẩn bị loại kho hết ngăn trống. |
| Thiết bị | Android emulator hoặc điện thoại khách; **hai điện thoại** để kiểm tra QR khách → camera staff. Đồng bộ giờ thiết bị và máy chủ với `Asia/Ho_Chi_Minh`. |
| Tích hợp | PostgreSQL dùng riêng cho thử nghiệm; email test có thể nhận thư; VNPay **sandbox** và merchant portal nếu muốn xác minh thanh toán/hoàn thật. Không dùng DB production hay thẻ thật. |

Mã booking, transaction ID, refund request ID và ảnh màn hình nên ghi riêng cho từng ca. Với kiểm thử thay đổi ngày/hết hạn, dùng DB test có thể khôi phục và ghi lại thời điểm đã chỉnh. Không đưa JWT, mật khẩu, hash secret hoặc dữ liệu thẻ vào biên bản.

### 1.2 Kiểm tra nhanh tự động trên Windows PowerShell

Tại thư mục gốc của repo:

```powershell
git switch dev
git pull --ff-only origin dev
git status --short
cd BE\StoreHub
```

Trên **DB test riêng, rỗng**, có thể tạo PostgreSQL bằng Docker một lần:

```powershell
docker run --name storehub-it-db -e POSTGRES_DB=storehub_it_local -e POSTGRES_PASSWORD=local-only-test -p 5433:5432 -d postgres:16
```

Nếu tên container đã tồn tại, chạy `docker start storehub-it-db`, rồi `docker exec storehub-it-db pg_isready -U postgres -d storehub_it_local`. Thiết lập biến trong **chính cửa sổ PowerShell chạy Maven**:

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
$env:VNPAY_TMN_CODE = "TESTONLY"
$env:VNPAY_HASH_SECRET = "integration-test-vnpay-secret"
$env:STOREHUB_INTEGRATION_TEST = "true"
$env:SPRING_FLYWAY_VALIDATE_ON_MIGRATE = "true"
$env:JAVA_TOOL_OPTIONS = "-Duser.timezone=Asia/Ho_Chi_Minh"
.\mvnw.cmd test
```

**Đạt:** `BUILD SUCCESS`, không có `Failures`/`Errors`. Suite gồm test service, security, callback và `ReservationDatabaseFlowTest` trên PostgreSQL thật. DB name của integration test phải bắt đầu bằng `storehub_it_`; bài này tạo/sửa dữ liệu. IPN trong test được ký giả lập, email mock; kết quả **không chứng minh** VNPay sandbox đã thu/hoàn. Xem thêm `STEP6_VERIFICATION.md` trong repo về G1–G3.

Với Flutter, quay lại thư mục gốc rồi chạy:

```powershell
cd ..\..\FE\storehub_mobile
flutter analyze
flutter test
flutter devices
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080/api/v1
```

Thay `192.168.1.10` bằng **IP LAN của PC đang chạy BE**, không gõ dấu `<` `>`; dùng cùng mạng Wi-Fi, mở cổng 8080. Android emulator có thể dùng `10.0.2.2` thay IP LAN nếu BE ở máy host. Nếu PowerShell mới không thấy Flutter:

```powershell
$env:Path = "C:\Program Files\flutter\flutter_windows_3.47.5-stable\flutter\bin;$env:Path"
```

**Đạt:** `flutter analyze` báo `No issues found!`, `flutter test` báo `All tests passed!`, app mở và gọi được API. Build release cần URL HTTPS public; HTTP LAN chỉ dành cho debug. Dùng cấu hình email/VNPay sandbox **thật của nhóm** khi thực hiện các ca E2E bên dưới, không dùng `TESTONLY` của bộ unit/integration test.

### 1.3 Quy ước

- `[ ]` = chưa chạy; `[x]` = đạt; ghi **FAIL/BLOCKED** và bằng chứng nếu lỗi hoặc thiếu điều kiện.
- Chỉ đổi `DB_URL`, chính sách, giờ hệ thống, trạng thái payment trên DB **thử nghiệm**. Muốn kiểm tra các nhánh mất IPN, hết hạn, lỗi email, dùng môi trường sandbox điều khiển được hoặc test tự động; không can thiệp giao dịch thật.
- Kết quả API cần đối chiếu cả HTTP, JSON `success/data`, booking/payment/unit trong DB test, app của **đúng role** và lịch sử giao dịch; đừng chỉ nhìn thông báo thành công.
- Màn hình có thể ghi tiếng Anh theo mã nguồn; đường đi bên dưới dùng đúng tên tab chính hoặc tên gần nhất.

## 2. Chức năng chung: tài khoản, phiên và phân quyền

| ID | Tính năng | Thao tác kiểm thử | Kết quả mong đợi |
| --- | --- | --- | --- |
| C01 [ ] | Đăng ký/đăng nhập | Đăng ký khách mới; thử đăng nhập đúng/sai mật khẩu; đăng nhập lần lượt 5 role. | Chỉ thông tin hợp lệ tạo khách; sai mật khẩu bị từ chối; mỗi role vào dashboard tương ứng. |
| C02 [ ] | Phân quyền API | Lấy JWT customer gọi API manager/staff/admin; staff A gọi API cơ sở B; customer B lấy booking/payment của A. | Bị từ chối; không lộ dữ liệu hay sửa dữ liệu chéo người/cơ sở. |
| C03 [ ] | Khôi phục phiên | Đăng nhập, đóng hẳn app và mở lại khi BE sẵn sàng; thử mất mạng khi mở app rồi bấm `Try again`. | Phiên hợp lệ được phục hồi; lỗi mạng có thể retry; không tự xóa dữ liệu booking. |
| C04 [ ] | Refresh/logout | Để access token hết hạn rồi thao tác; logout và mở lại app. | Refresh hợp lệ tiếp tục phiên; logout xóa phiên local và không tự vào dashboard. Kiểm thêm kỳ vọng bảo mật với token cũ cho đến khi hết hạn. |
| C05 [ ] | Quên/đổi mật khẩu | Gửi email reset; mở `storehub://reset-password?token=...` trên điện thoại khi app đóng/mở; đặt mật khẩu mới và đổi mật khẩu trong profile. | Link vào form đúng token; token sai/hết hạn không dùng được; mật khẩu mới đăng nhập được, mật khẩu cũ không. |
| C06 [ ] | Admin người dùng | `System Administration` → `Users & Role Assignment`: tìm, phân trang, bật/tắt user, đổi role. `Roles & Permissions (RBAC)` và `Activity Log`: xem/cập nhật trong quyền admin. | Tài khoản bị khóa không đăng nhập được; role/permission và log thay đổi đúng; role thấp không sửa được. |
| C07 [ ] | Gán chi nhánh | Admin → `Facility Management` gán facility manager; manager → tab `Staff` gán/tháo staff. | Manager/staff nhìn thấy đúng cơ sở; staff cơ sở khác không thể nhận lịch/ticket. |
| C08 [ ] | Danh sách dài | Tạo > một trang user, ticket, refund và lịch sử giao dịch; thử `Load more`/chuyển trang và tải lại. | Không bỏ sót, không lặp bản ghi, thứ tự và bộ lọc giữ ổn định. |

## 3. Flow 1 — Storage Unit Reservation (Thành)

**Chức năng:** catalog cơ sở/loại/ngăn, lọc vị trí/diện tích/máy lạnh 24/7, chi tiết cơ sở, báo giá theo ngày và kỳ thuê, giữ ngăn dự kiến, lịch nhận kho, thanh toán cọc/tiền thuê qua VNPay, hủy/hết hạn booking, waitlist, khôi phục đơn chờ và xem lịch sử thanh toán.

| ID | Tính năng và đường đi | Thao tác kiểm thử | Kết quả mong đợi |
| --- | --- | --- | --- |
| F1-01 [ ] | `Customer` → `Explore` | Tìm theo tên/địa chỉ; lọc diện tích, máy lạnh 24/7; xem loại, diện tích, giá, số ngăn còn. | Chỉ cơ sở phù hợp và còn hoạt động; dữ liệu/giá/số lượng khớp catalog; cơ sở ngừng hoạt động không đặt được dù gọi trực tiếp API. |
| F1-02 [ ] | `Facility Detail` → báo giá | Chọn loại kho, ngày/giờ hẹn, 1 và nhiều tháng; thay lựa chọn và xem breakdown cọc, thuê, phụ phí. | Số tiền cập nhật từ BE, không thu tiền ở bước báo giá; ngày/giờ và kỳ thuê không hợp lệ bị từ chối; giới hạn thuê tối đa 36 tháng. |
| F1-03 [ ] | Đặt chỗ | Tạo booking khi còn ngăn; ghi booking code, unit dự kiến và thời điểm hết hạn; thử hai khách chọn ngăn cuối gần đồng thời. | Booking `PENDING_PAYMENT`, ngăn được giữ `RESERVED`, không cấp cùng một ngăn cho hai booking. Mã ngăn trước manager xác nhận phải được thể hiện là **dự kiến**. |
| F1-04 [ ] | `Payment` → VNPay sandbox | Thanh toán thành công, trở về app, đợi IPN rồi refresh và xem `Transaction History`. | Đối chiếu trên portal: khoản cọc và thuê `PAID`, booking `CONFIRMED`, tiền không bị ghi hai lần; màn app cho thấy trạng thái xác nhận. |
| F1-05 [ ] | Retry/đóng app giữa thanh toán | Mở URL thanh toán rồi đóng app; quay lại `Home`/đơn chờ; thử URL hết hạn hoặc thanh toán lỗi rồi khởi tạo lại. | Booking còn hạn có thể tiếp tục tạo payment attempt mới; attempt cũ không xác nhận nhầm hoặc thu lặp; sau IPN trạng thái thống nhất. |
| F1-06 [ ] | Hủy/hết hạn/IPN muộn | Hủy booking chờ; để đơn quá 30 phút rồi kiểm tra job; kiểm IPN thành công đến sau khi booking đã hủy/hết hạn trên sandbox kiểm soát được. | Ngăn trở lại `AVAILABLE`; booking không sống lại; khoản thật sự đã thu được đưa vào đối soát/yêu cầu hoàn và không hoàn hai lần. |
| F1-07 [ ] | Chính sách hủy | Hủy booking đã thu tiền ở nhiều mốc trước/sát giờ check-in dự kiến. | Bậc hoàn tính theo **giờ hẹn**, số tiền hoàn/giữ khớp policy; khoản hoàn chỉ `COMPLETED` sau đối soát cổng. Nếu app không có nút cho trường hợp này, thử API/case integration. |
| F1-08 [ ] | Waitlist | Khi loại hết kho, khách A vào `My waitlist`; giải phóng ngăn; kiểm email/thông báo và TTL; khách rời danh sách hoặc đặt được ngăn. | Trạng thái `WAITING → NOTIFIED → FULFILLED/EXPIRED/CANCELLED` đúng, không gửi trùng; nếu email lỗi, scheduler vẫn có cơ hội retry. |

**Ca lỗi bổ sung:** loại kho hết ngăn, cơ sở inactive, quote lỗi, số tháng âm/0/>36, khởi tạo thanh toán hai lần, IPN chữ ký sai/gửi trùng, booking của người khác, email xác nhận thất bại. Xác nhận các ca đều giữ nguyên bất biến tiền, booking, ngăn.

## 4. Flow 2 — Storage Check-in and Handover (Bảo)

**Chức năng:** manager xác nhận/đổi ngăn vật lý, phân công lịch nhận/trả; staff xem lịch ngày theo cơ sở, ghi biên bản tình trạng khóa/vệ sinh, bàn giao nhận kho, nghiệm thu trả kho, sinh yêu cầu hoàn cọc và theo dõi xử lý hoàn.

| ID | Tính năng và đường đi | Thao tác kiểm thử | Kết quả mong đợi |
| --- | --- | --- | --- |
| F2-01 [ ] | Manager → `Confirmed Bookings` | Xem đơn vừa `CONFIRMED`; xác nhận ngăn dự kiến hoặc đổi sang ngăn trống cùng loại trước khi giao. | Mã ngăn chính thức cập nhật ở booking/khách; khách nhận email cập nhật; ngăn cũ trở lại khả dụng và kích hoạt waitlist; không đổi ngăn đã bị giữ/khác cơ sở. |
| F2-02 [ ] | Manager → phân công lịch | Gán staff A cho check-in, staff B cho check-out; thử gán staff cơ sở B/đã khóa. | Lịch của staff đúng ngày, giờ, loại hẹn, khách/ngăn; từ chối staff không hợp lệ; chỉ đúng người được phân công thao tác. |
| F2-03 [ ] | Staff → `Staff Operations` | Chọn ngày và cơ sở, xem lịch nhận/trả và lịch sử biên bản; thử staff không được gán. | Chỉ lịch cơ sở và quyền được giao; danh sách nhận/trả thể hiện thời gian; staff khác không nhận nhầm. |
| F2-04 [ ] | Check-in/biên bản giao | Với booking đã thu và ngăn đã xác nhận, ghi tình trạng ngăn, khóa, vệ sinh/ghi chú, xác nhận. Bấm lặp hai lần. | Có **một** biên bản giao, booking `ACTIVE`, ngăn `OCCUPIED`; Smart Key xuất hiện cho khách, thao tác lặp bị chặn. |
| F2-05 [ ] | Trả kho đúng hạn | Khách đặt lịch checkout (Flow 3); staff đúng lịch kiểm tra và ghi biên bản nhận lại. | Booking `COMPLETED`, ngăn `UNDER_MAINTENANCE`, lịch sử có biên bản trả; tạo yêu cầu hoàn cọc đúng chính sách, **chưa** ghi hoàn thành tiền trước khi cổng xác nhận. |
| F2-06 [ ] | Trả kho quá hạn/chưa chạy job | Trong DB test, tạo booking ACTIVE đã qua hạn chịu phí nhưng chưa có payment phí; gọi checkout khi chưa chạy job 00:05. | Checkout bị chặn, tạo nợ phí thiếu để khách thanh toán, không đóng booking/không hoàn cọc; thử lại sau khi trả phí mới nghiệm thu được. Kiểm thêm reload DB để biết nợ đã commit. |
| F2-07 [ ] | Phí thất bại và kiểm tra lại | Cho thanh toán phí quá hạn thất bại; thử checkout, trả phí lại, rồi checkout; gọi lặp. | Nợ `FAILED` vẫn được nhận diện và có đường retry; không gia hạn/hoàn cọc lúc còn nợ; không nhân đôi tiền hoặc biên bản. |
| F2-08 [ ] | Manager → `Refund requests` | Xem danh sách nhiều trang/ưu tiên hồ sơ mở/quá SLA; bổ sung metadata giao dịch gốc, retry khi bị từ chối, `Check with VNPay`. | Không mất hồ sơ cũ ở trang sau; SLA hiện rõ; trạng thái `MISSING_METADATA/QUEUED/SENDING/AWAITING_CONFIRMATION/NEEDS_REVIEW/REJECTED/COMPLETED` phản ánh cổng; không gửi hoàn trùng. |

**Kiểm tra bằng sandbox:** so số tiền hoàn với giao dịch gốc trong merchant portal; mô phỏng mất phản hồi hoàn và đối soát trước khi retry. Biên bản hư hỏng/cần bảo trì phải được lưu; chính sách khấu trừ cọc cần đối chiếu kết quả thực tế với policy của cơ sở.

## 5. Flow 3 — Rented Storage Unit Management

**Chức năng:** `My Units`, thời hạn hợp đồng, Smart Access PIN và QR cổng, gia hạn và trả phí, yêu cầu lịch trả kho, phí quá hạn, ticket hỗ trợ, lịch sử giao dịch.

| ID | Tính năng và đường đi | Thao tác kiểm thử | Kết quả mong đợi |
| --- | --- | --- | --- |
| F3-01 [ ] | Customer → `My Units` | Sau check-in xem mã ngăn, vị trí, cơ sở, ngày hết hạn, trạng thái; xem đơn chờ bàn giao. | Chỉ kho của khách, danh sách ACTIVE đúng; booking chưa check-in/đã COMPLETED không bị hiển thị như đang thuê. |
| F3-02 [ ] | `Smart Key` → PIN | Tự đặt hoặc nhận mã 6 số một lần; mở/đóng; đổi bằng PIN cũ; quên PIN bằng mật khẩu hoặc staff reset tại quầy. | Mã mới hoạt động, mã cũ hết hiệu lực, nhập sai bị trừ lượt và khóa tạm khi vượt ngưỡng; mã không được trả lại tùy tiện. Khóa ở đây là **trạng thái phần mềm mô phỏng**, chưa điều khiển thiết bị vật lý. |
| F3-03 [ ] | Customer QR → staff camera | Khách tạo QR; staff mở `Gate QR verification` và dùng camera điện thoại thứ hai quét. Thử quét lại cùng QR, QR hết 90 giây, QR khác cơ sở/khác booking. | QR hợp lệ chỉ dùng một lần và đúng cơ sở; mã dùng lại/hết hạn/sai cơ sở bị từ chối; camera xử lý quyền truy cập bị từ chối rõ ràng. |
| F3-04 [ ] | Gia hạn hợp đồng | Từ `My Units` → `Extend Rental`, chọn số tháng; so ngày dự kiến trả từ BE (thử hợp đồng 31/01), số tiền và URL VNPay; thanh toán rồi refresh. | End date chỉ đổi khi đã thu tiền hợp lệ; báo giá và ngày đầu/cuối tháng thống nhất BE/FE; có thể hủy yêu cầu chưa trả mà không tạo hợp đồng ma. |
| F3-05 [ ] | Gia hạn thất bại/IPN muộn | Mở payment gia hạn, hủy yêu cầu trước khi IPN đến; gửi callback muộn/đúp trong môi trường test. | Hợp đồng không gia hạn ngoài ý muốn; khoản thu muộn cần hoàn/đối soát; nợ trễ hạn còn tồn tại thì chặn gia hạn. |
| F3-06 [ ] | Trả phí quá hạn | Đưa booking ACTIVE qua `endDate`, trong/qua số ngày miễn phí theo policy; xem khoản phải trả, cho payment `FAILED`, retry. | Phí cộng theo số ngày chịu phí, phần nợ cũ không biến mất, số tiền có thể tăng theo ngày; sau khi trả hết mới được nghiệm thu trả. PIN/QR/UI nhất quán với mốc khóa truy cập của policy. |
| F3-07 [ ] | `Request Checkout` | Chọn **ngày và giờ** trả kho, xác nhận rồi mở lịch manager/staff. | Lịch checkout đúng giờ, booking còn ACTIVE cho tới nghiệm thu; không tạo trùng lịch hoặc trả kho sai chi nhánh. |
| F3-08 [ ] | `Support` | Tạo ticket các loại (quên mã, kẹt khóa, hư hỏng...), nhập mô tả, xem danh sách/chi tiết; thử > một trang. | Ticket thuộc đúng khách/cơ sở, trạng thái ban đầu OPEN; thấy staff được giao và các cập nhật; không truy cập ticket khách khác. |

## 6. Flow 4 — Business Rules, Fee Management, Revenue Monitoring (Nguyên)

**Chức năng:** policy theo cơ sở (cọc, mức phí quá hạn, miễn phí, khóa truy cập, mốc hủy/hoàn, SLA hoàn), giá từng loại ngăn, quyền admin/RBAC, activity log, biểu đồ doanh thu, xuất báo cáo và lấp đầy.

| ID | Tính năng và đường đi | Thao tác kiểm thử | Kết quả mong đợi |
| --- | --- | --- | --- |
| F4-01 [ ] | Business manager → `Facilities & Policies` | Tạo/sửa policy trên cơ sở A, xem lại; thay mức cọc/biểu phí, ngưỡng quá hạn, mức hoàn, `depositRefundSlaDays`. | Quote **mới** dùng policy mới; đơn đã tạo dùng snapshot cần thiết; dữ liệu không hợp lệ bị từ chối; SLA hồ sơ hoàn được tính/hiển thị. |
| F4-02 [ ] | `Unit Prices` | Sửa giá của loại kho rồi lấy quote mới; kiểm booking cũ. | Quote mới theo giá mới; khoản đã thu cũ không bị sửa hồi tố. |
| F4-03 [ ] | Trễ hạn và chính sách | Với booking ACTIVE quá endDate, kiểm job 00:05 và checkout khi job không chạy, miễn phí, mức phí, thời điểm khóa PIN/QR. | Mỗi ngày chỉ tính một lần phần tăng thêm; nợ PENDING/FAILED không bị bỏ qua; checkout không xóa nợ; toàn bộ truy cập tuân cùng policy. |
| F4-04 [ ] | Hủy và hoàn tiền | Hủy tại mốc trước/sát lịch nhận, trả kho đúng/trễ hạn và có hư hỏng; đối chiếu số tiền cọc hoàn. | Mức hoàn bám policy và thời điểm hẹn; refund chỉ chốt khi cổng xác nhận; SLA cần xử lý hiện ở màn review. |
| F4-05 [ ] | `Revenue & Occupancy Reports` | Tạo khoản thu kỳ A, hoàn tiền kỳ B; lọc tháng, cơ sở; so chart, API `/reports/revenue`, export. | Doanh thu ròng kỳ A **giữ nguyên khoản thu gốc**, kỳ B ghi khoản hoàn âm; tiền cọc báo cáo riêng; `paymentCount` đếm khoản thu; export khớp màn hình. |
| F4-06 [ ] | Lấp đầy | Tạo/hủy/nhận/trả booking rồi so `/reports/occupancy`, report facility và lưới ngăn. | Số AVAILABLE/RESERVED/OCCUPIED/UNDER_MAINTENANCE, tỷ lệ lấp đầy khớp trạng thái thật, không đếm ngăn đã bị khóa sai. |
| F4-07 [ ] | Admin và nhật ký | Thay role, permission, tài khoản, policy; thử user thường gọi API admin. | Phân quyền thật ở BE; log đăng nhập và thao tác có actor/thời điểm; không rò dữ liệu giữa role. |
| F4-08 [ ] | Quá hạn/niêm phong | Cho hợp đồng vượt mốc khóa và mốc chờ niêm phong theo policy; manager vào `Contracts` → `Approve sealing`. | PIN/QR bị chặn khi hết quyền; yêu cầu duyệt niêm phong chỉ xuất hiện đúng ngưỡng, chỉ manager đúng cơ sở phê duyệt và có log. Không diễn giải thao tác này thành việc khóa cửa vật lý. |

## 7. Flow 5 — Facility Storage and Staff Management (Bảo)

**Chức năng:** cơ sở, ngăn vật lý, sơ đồ trạng thái, manager/staff cơ sở, lịch ngày, phân công check-in/check-out, ticket, báo cáo chi nhánh, xử lý ngăn sau trả và waitlist.

| ID | Tính năng và đường đi | Thao tác kiểm thử | Kết quả mong đợi |
| --- | --- | --- | --- |
| F5-01 [ ] | Manager → `Units` | Xem ngăn theo cơ sở/trạng thái/vị trí; tạo và sửa mã ngăn/loại/tầng; thử trùng mã, sửa ngăn đang có khách. | Chỉ ngăn cơ sở quản lý, màu và số liệu khớp `AVAILABLE/RESERVED/OCCUPIED/UNDER_MAINTENANCE`; không phá booking active. |
| F5-02 [ ] | Vòng đời ngăn | Theo dõi đặt chỗ → nhận kho → trả kho → vệ sinh/bảo trì → mở lại. | AVAILABLE → RESERVED → OCCUPIED → UNDER_MAINTENANCE → AVAILABLE theo thao tác hợp lệ; không mở bán khi chưa sẵn sàng; khi giải phóng báo waitlist. |
| F5-03 [ ] | Manager → `Staff` | Gán staff A/B; tháo staff; thử dùng tài khoản inactive hoặc staff thuộc cơ sở khác. | Phân quyền cơ sở đúng; lịch/ticket đang được giao xử lý theo quy tắc; staff bị tháo không thao tác cơ sở cũ. |
| F5-04 [ ] | Lịch và phân công | Manager phân công ngày nhận/trả, staff xem `Staff Operations` trong ngày khác nhau. | Staff chỉ thấy việc được phân công và đúng giờ; thao tác trái phân công/chi nhánh bị từ chối. |
| F5-05 [ ] | Manager `Tickets` → staff `Staff Tickets` | Manager giao ticket, staff nhận ticket chưa giao, đổi `OPEN → IN_PROGRESS → RESOLVED/CLOSED`; tải thêm danh sách. | Chỉ staff cơ sở hợp lệ nhận việc; khách nhìn được trạng thái; phân trang không bỏ sót; không hai người cùng chiếm ticket khi thao tác đồng thời. |
| F5-06 [ ] | `Report` của manager | So số ngăn trống/đang thuê và tình trạng bảo trì trước/sau check-in/check-out. | Báo cáo chỉ của cơ sở được giao và bằng tổng ngăn thực tế theo trạng thái. |
| F5-07 [ ] | Đổi ngăn đã giữ | Manager đổi ngăn cùng loại cho booking đã confirmed; khách kiểm thông báo, waitlist. | Không cấp trùng, ngăn cũ sẵn sàng/notify ngay, mã dự kiến được thay bằng mã chính thức; customer không tới nhầm ngăn. |

## 8. Kịch bản liên flow để trình diễn trên app thật

1. [ ] **A — Hành trình thành công:** Admin tạo/gán cơ sở, business manager đặt policy/giá → customer lọc 24/7 và đặt hẹn → trả tiền sandbox → manager xác nhận ngăn và phân staff → staff check-in → khách xem `My Units`, mở PIN và tạo QR → staff dùng camera xác thực → customer gia hạn và trả tiền → đặt lịch trả → staff check-out → manager theo dõi hoàn → báo cáo kỳ thu/kỳ hoàn. Ghi trạng thái booking/unit/payment/refund sau mỗi bước.
2. [ ] **B — Booking thất bại:** hai khách tranh ngăn cuối, một khách chưa trả tiền/hủy, IPN đến muộn; không trùng ngăn, không hồi sinh booking, khoản thu muộn được xử lý hoàn.
3. [ ] **C — Quá hạn:** tạo hợp đồng đã quá hạn trong DB test, không chạy job, staff thử checkout; hệ thống ghi nợ rồi chặn, khách trả phí, staff thử lại và hoàn cọc đúng. Kiểm DB thật để chắc nợ còn sau lỗi API.
4. [ ] **D — Phân quyền và nhánh khác:** staff/manager chi nhánh B thử đơn A, customer B thử kho và ticket của A, token không hợp lệ. Không xem hoặc sửa dữ liệu ngoài phạm vi.
5. [ ] **E — Mạng yếu và khởi động lại:** mất mạng khi restore phiên, đang thanh toán, mở deep link reset; thử retry, callback lặp và refresh màn. Không tạo tiền hoặc lịch hai lần.
6. [ ] **F — Doanh thu khác kỳ:** thu trong tháng A, hoàn trong tháng B trên sandbox/DB test; chart và export phản ánh dòng tiền từng kỳ đúng như F4-05.

## 9. Cổng kiểm chứng trước khi gọi “hoàn tất”

| Cổng | Cần đạt |
| --- | --- |
| Tĩnh và unit | Maven `BUILD SUCCESS`; `flutter analyze` sạch; `flutter test` qua. Đây chỉ là một phần bằng chứng. |
| DB integration | Flyway chạy trên PostgreSQL test mới; `ReservationDatabaseFlowTest` và các test payment/overdue/refund chạy qua; API checkout quá hạn vẫn **lưu khoản nợ** sau khi trả lỗi. |
| VNPay sandbox | Return URL/IPN **HTTPS public** cấu hình đúng; portal khớp giao dịch thu, thất bại, hoàn toàn phần/một phần, mất phản hồi và đối soát; không dùng URL emulator cho IPN. |
| Email/deep link | Mail xác nhận đơn, mã ngăn sau xác nhận, waitlist, reset mật khẩu đến hộp thư test; link mở app khi đang chạy hoặc đã đóng. |
| Thiết bị | Một Android debug kết nối BE; hai máy test camera QR; nút PIN/khóa chỉ mô phỏng logic nếu chưa có phần cứng, không coi là thử nghiệm khóa cửa thật. |
| Cấu hình chạy thật | `prod` dùng HTTPS, biến môi trường bí mật, múi giờ nghiệp vụ `Asia/Ho_Chi_Minh`, không seed demo; backup DB trước migration trên dữ liệu có thật. |

## 10. Mẫu ghi kết quả và báo lỗi

| Ngày/giờ (GMT+7) | Commit | Thiết bị / BE / DB | Test ID | PASS / FAIL / BLOCKED | Booking/transaction/refund ID | Kết quả thực tế và bằng chứng |
| --- | --- | --- | --- | --- | --- | --- |
| … | … | … | F2-06 | … | … | … |

Khi báo lỗi, ghi **dữ liệu đầu vào → thao tác → kết quả mong đợi → kết quả thực tế → các trạng thái ở app/API/DB/portal**. Kèm log đã che thông tin nhạy cảm. Nếu chỉ thiếu VNPay sandbox, thiết bị thứ hai hoặc email thật, ghi `BLOCKED` cho đúng ca; không đánh dấu PASS vì unit test thành công.
