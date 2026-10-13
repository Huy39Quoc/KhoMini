# KhoMini — Luồng thao tác nhanh cho 5 flow

> Bản đơn giản để trình bày và thử trên app. Dấu `→` là bước tiếp theo; các nhánh trong ngoặc là trường hợp cần thử thêm. Backend và app cùng dùng các trạng thái của booking, ngăn kho và thanh toán.

## Bắt đầu: tài khoản

**Khách:** đăng ký/đăng nhập → vào trang khách hàng.  
**Nhân viên / quản lý chi nhánh / quản lý vận hành / admin:** đăng nhập → vào trang đúng vai trò.  
**Thử nhanh:** sai mật khẩu, tài khoản bị khóa, đăng xuất, đóng rồi mở lại app, quên mật khẩu qua email.

## Flow 1 — Tìm kho, đặt chỗ và thanh toán

**Khách hàng:** đăng nhập → **Explore** → tìm chi nhánh → lọc diện tích/máy lạnh 24/7 → xem loại kho và giá → chọn ngày giờ nhận kho, số tháng thuê → xem báo giá → đặt chỗ → thanh toán VNPay → nhận xác nhận đặt chỗ.

**Sau đó:** đơn `PENDING_PAYMENT` → thanh toán thành công → đơn `CONFIRMED`, ngăn được giữ cho khách; **mã ngăn chỉ là dự kiến** cho đến khi quản lý xác nhận.

**Thử thêm:** hủy hoặc để đơn hết hạn → ngăn được giải phóng; không còn ngăn → tham gia waitlist; thanh toán lỗi → thử lại; đơn đã hủy nhưng IPN đến muộn → không tự xác nhận lại đơn.

## Flow 2 — Nhận kho, bàn giao và trả kho

**Quản lý chi nhánh:** mở danh sách đơn đã xác nhận → xác nhận/đổi ngăn thực tế → gán nhân viên cho lịch nhận kho và trả kho.  
**Nhân viên:** đăng nhập → xem lịch hôm nay → gặp khách → kiểm tra khóa/tình trạng kho → lập biên bản → bấm **Check-in**.  
**Kết quả:** đơn `ACTIVE`, ngăn `OCCUPIED`, khách sử dụng được Smart Key.

**Khi trả kho:** khách đặt lịch trả → nhân viên được giao kiểm tra ngăn → lập biên bản nhận lại → **Check-out** → đơn `COMPLETED`, ngăn chờ vệ sinh/bảo trì → tạo yêu cầu hoàn cọc → đối soát và hoàn tiền qua VNPay.

**Thử thêm:** nhân viên không được giao không thể nhận/trả; còn nợ phí quá hạn thì chưa được hoàn tất trả kho hoặc hoàn cọc; hoàn tiền lỗi thì quản lý xem hồ sơ và đối soát.

## Flow 3 — Quản lý kho đang thuê

**Khách hàng:** đăng nhập → **My Units** → xem kho đang thuê, vị trí và ngày hết hạn → **Smart Key** → tạo/đổi PIN → mở/đóng khóa mô phỏng; tạo QR cổng → nhân viên dùng camera quét QR.

**Gia hạn:** chọn kho → **Extend Rental** → chọn số tháng → xem tiền/ngày mới → trả phí qua VNPay → hợp đồng cập nhật ngày hết hạn.  
**Trả kho:** chọn kho → **Request Checkout** → chọn ngày giờ → gửi yêu cầu → đợi nhân viên nghiệm thu theo Flow 2.  
**Hỗ trợ:** **Support** → chọn loại sự cố → nhập mô tả → gửi ticket → theo dõi trạng thái xử lý.

**Thử thêm:** PIN sai nhiều lần bị chặn tạm; QR hết hạn/dùng lại bị từ chối; gia hạn chưa trả tiền thì ngày hết hạn chưa đổi; phí quá hạn phải trả trước khi hoàn tất trả kho. Nút mở khóa trong app mới cập nhật **trạng thái mô phỏng**, chưa điều khiển khóa vật lý.

## Flow 4 — Chính sách, phí và báo cáo

**Quản lý vận hành:** đăng nhập → **Facilities & Policies** → đặt mức cọc, quy tắc hủy/hoàn, phí quá hạn, thời hạn hoàn cọc → chỉnh giá loại kho → khách nhận báo giá theo chính sách mới.

**Theo dõi:** mở **Revenue & Occupancy Reports** → chọn kỳ/cơ sở → xem biểu đồ doanh thu và tỷ lệ lấp đầy → đối chiếu/xuất báo cáo. Tiền hoàn được ghi vào **kỳ hoàn**, còn khoản thu ban đầu vẫn thuộc **kỳ thu**.

**Admin:** đăng nhập → quản lý tài khoản, role/quyền và gán quản lý chi nhánh → xem nhật ký hoạt động.

**Thử thêm:** đổi giá không sửa khoản đã thu; phí quá hạn tăng theo số ngày chịu phí; người không có quyền không sửa chính sách hoặc xem dữ liệu admin.

## Flow 5 — Quản lý chi nhánh, ngăn và nhân viên

**Quản lý chi nhánh:** đăng nhập → **Units** → xem các ngăn trống/đã giữ/đang thuê/cần bảo trì → tạo hoặc sửa ngăn → **Staff** → phân công nhân viên → phân công lịch nhận/trả → **Tickets** → giao yêu cầu hỗ trợ → **Report** → xem số liệu chi nhánh.

**Nhân viên:** đăng nhập → xem lịch/việc được giao → bàn giao hoặc nhận lại kho → xử lý ticket → cập nhật tình trạng ngăn sau vệ sinh/bảo trì.

**Trạng thái ngăn:** `AVAILABLE` (trống) → `RESERVED` (đã giữ) → `OCCUPIED` (đang thuê) → `UNDER_MAINTENANCE` (chờ xử lý) → `AVAILABLE` (sẵn sàng đặt tiếp).

**Thử thêm:** nhân viên chi nhánh khác không xử lý đơn; đổi ngăn cho booking không được cấp trùng; ngăn được giải phóng thì người trong waitlist được báo.

## Chạy thử một lượt từ đầu đến cuối

1. **Admin** gán quản lý chi nhánh → **quản lý vận hành** đặt giá/chính sách → **quản lý chi nhánh** tạo ngăn và gán nhân viên.
2. **Khách** tìm kho → đặt lịch → thanh toán → **quản lý chi nhánh** xác nhận ngăn và gán lịch.
3. **Nhân viên** check-in → **khách** thử PIN/QR, gia hạn hoặc gửi ticket.
4. **Khách** đặt lịch trả → **nhân viên** check-out → **quản lý chi nhánh** theo dõi hoàn cọc.
5. **Quản lý vận hành** kiểm tra doanh thu, khoản hoàn và tỷ lệ lấp đầy; **quản lý chi nhánh** kiểm tra ngăn đã chuyển sang bảo trì.

**Cách đánh giá nhanh:** ở mỗi mũi tên, xem màn hình của **cả người thực hiện và người nhận việc**, rồi kiểm tra trạng thái booking, payment và ngăn kho đã đổi đúng chưa. Muốn kiểm tra từng ca lỗi và lệnh chạy cụ thể, dùng tài liệu chi tiết `KhoMini_Test_Plan_Flow_1-5_dev_9080813.md`.
