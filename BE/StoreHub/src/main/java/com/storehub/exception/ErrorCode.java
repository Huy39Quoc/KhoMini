package com.storehub.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public enum ErrorCode {

    // ========================= ROLE (100 - 199) =========================
    ROLE_NOT_FOUND(100, "Không tìm thấy vai trò", HttpStatus.NOT_FOUND),
    ROLE_NAME_EXISTED(101, "Tên vai trò đã tồn tại", HttpStatus.BAD_REQUEST),
    CANNOT_DELETE_SYSTEM_ROLE(102, "Không thể xóa vai trò mặc định của hệ thống", HttpStatus.FORBIDDEN),
    CANNOT_MODIFY_SYSTEM_ROLE(103, "Không thể đổi tên vai trò mặc định của hệ thống", HttpStatus.FORBIDDEN),
    ROLE_IN_USE(104, "Không thể xóa vai trò đang được gán cho người dùng", HttpStatus.CONFLICT),
    ROLE_INACTIVE(105, "Vai trò đã bị vô hiệu hóa", HttpStatus.BAD_REQUEST),

    // ========================= USER (200 - 299) =========================
    USER_NOT_FOUND(200, "Không tìm thấy người dùng", HttpStatus.NOT_FOUND),
    USER_ALREADY_EXISTS(201, "Tên đăng nhập đã tồn tại", HttpStatus.BAD_REQUEST),
    EMAIL_ALREADY_EXISTS(202, "Email đã được sử dụng", HttpStatus.BAD_REQUEST),
    USER_INACTIVE(203, "Tài khoản đã bị vô hiệu hóa", HttpStatus.FORBIDDEN),

    // ========================= AUTH (300 - 399) =========================
    INVALID_CREDENTIALS(300, "Email hoặc mật khẩu không đúng", HttpStatus.UNAUTHORIZED),
    UNAUTHORIZED(301, "Vui lòng đăng nhập để tiếp tục", HttpStatus.UNAUTHORIZED),
    FORBIDDEN(302, "Bạn không có quyền truy cập chức năng này", HttpStatus.FORBIDDEN),

    // ========================= TOKEN (400 - 499) =========================
    INVALID_TOKEN(400, "Phiên đăng nhập không hợp lệ", HttpStatus.UNAUTHORIZED),
    TOKEN_EXPIRED(401, "Phiên đăng nhập đã hết hạn", HttpStatus.UNAUTHORIZED),
    TOKEN_REVOKED(402, "Phiên đăng nhập đã bị thu hồi", HttpStatus.UNAUTHORIZED),
    INVALID_REFRESH_TOKEN(403, "Phiên đăng nhập không hợp lệ", HttpStatus.UNAUTHORIZED),

    // ========================= PASSWORD (500 - 599) =========================
    PASSWORD_MISMATCH(500, "Mật khẩu xác nhận không khớp", HttpStatus.BAD_REQUEST),
    INVALID_OLD_PASSWORD(501, "Mật khẩu hiện tại không đúng", HttpStatus.BAD_REQUEST),
    NEW_PASSWORD_SAME_AS_OLD(502, "Mật khẩu mới phải khác mật khẩu cũ", HttpStatus.BAD_REQUEST),
    INVALID_RESET_TOKEN(503, "Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn", HttpStatus.BAD_REQUEST),

    // ========================= SYSTEM (600 - 699) =========================
    INTERNAL_SERVER_ERROR(600, "Lỗi hệ thống, vui lòng thử lại sau", HttpStatus.INTERNAL_SERVER_ERROR),
    INVALID_REQUEST(601, "Yêu cầu không hợp lệ hoặc không phù hợp với trạng thái hiện tại", HttpStatus.BAD_REQUEST),

    // ========================= BOOKING & ACCESS (700 - 799) =================
    BOOKING_NOT_FOUND(700, "Không tìm thấy đơn đặt kho hoặc đơn không thuộc về bạn", HttpStatus.NOT_FOUND),
    BOOKING_NOT_CHECKED_IN(701, "Ngăn kho chưa được bàn giao cho khách", HttpStatus.FORBIDDEN),
    INVALID_PIN_FORMAT(702, "Mã PIN phải gồm đúng 6 chữ số", HttpStatus.BAD_REQUEST),
    UNIT_TYPE_NOT_FOUND(703, "Không tìm thấy loại kho", HttpStatus.NOT_FOUND),
    STORAGE_UNIT_NOT_FOUND(704, "Không tìm thấy ngăn kho", HttpStatus.NOT_FOUND),
    INVALID_PRICING_TARGET(705, "Chỉ được cung cấp một trong hai: loại kho hoặc ngăn kho", HttpStatus.BAD_REQUEST),
    UNIT_TYPE_PRICE_NOT_CONFIGURED(706, "Loại kho chưa được cấu hình giá thuê tháng", HttpStatus.INTERNAL_SERVER_ERROR),
    NO_AVAILABLE_UNIT(707, "Hiện không còn ngăn kho trống thuộc loại đã chọn tại cơ sở này", HttpStatus.CONFLICT),
    BOOKING_EXPIRED(708, "Đơn đặt kho đã hết hạn giữ chỗ. Vui lòng đặt lại.", HttpStatus.GONE),
    BOOKING_CANCEL_NOT_ALLOWED(711, "Chỉ có thể hủy đơn đang chờ thanh toán hoặc đã xác nhận", HttpStatus.CONFLICT),
    EXTENSION_ALREADY_PENDING(712, "Đơn này đang có yêu cầu gia hạn chờ thanh toán. Vui lòng thanh toán hoặc chờ xử lý xong.", HttpStatus.CONFLICT),
    RENEWAL_WINDOW_NOT_REACHED(713, "Chưa đến thời điểm được gia hạn theo chính sách của cơ sở", HttpStatus.FORBIDDEN),
    RETURN_NOTICE_NOT_SATISFIED(714, "Giờ hẹn trả kho chưa đáp ứng thời gian báo trước tối thiểu của cơ sở", HttpStatus.BAD_REQUEST),
    ACCESS_DISABLED_OVERDUE(715, "Quyền truy cập ngăn kho đã bị khóa do quá hạn thuê. Vui lòng thanh toán phí trễ hạn rồi gia hạn hoặc trả kho.", HttpStatus.FORBIDDEN),
    OVERDUE_FEE_UNPAID(716, "Vui lòng thanh toán phí trễ hạn trước khi gia hạn", HttpStatus.CONFLICT),
    NO_PENDING_EXTENSION(717, "Đơn này không có yêu cầu gia hạn đang chờ", HttpStatus.NOT_FOUND),
    PIN_NOT_SET(718, "Ngăn kho chưa có mã PIN. Vui lòng tạo mã PIN trước.", HttpStatus.CONFLICT),
    PIN_ALREADY_SET(719, "Ngăn kho đã có mã PIN. Hãy đổi PIN, hoặc đặt lại PIN nếu bạn quên.", HttpStatus.CONFLICT),
    PIN_INCORRECT(720, "Mã PIN không đúng", HttpStatus.BAD_REQUEST),
    PIN_TEMPORARILY_LOCKED(721, "Nhập sai PIN quá nhiều lần. Vui lòng thử lại sau hoặc đặt lại PIN bằng mật khẩu tài khoản.", HttpStatus.LOCKED),
    PIN_RESET_PASSWORD_INCORRECT(722, "Mật khẩu tài khoản không đúng", HttpStatus.BAD_REQUEST),
    CHECKIN_TOO_EARLY(723, "Chỉ được bàn giao kho từ ngày bắt đầu thuê", HttpStatus.BAD_REQUEST),
    RESOURCE_IN_USE(724, "Dữ liệu này đang được sử dụng nên không thể xóa. Hãy vô hiệu hóa thay thế.", HttpStatus.CONFLICT),
    UNIT_NOT_OVERDUE(725, "Đơn này không ở trạng thái chờ niêm phong", HttpStatus.CONFLICT),
    RENTAL_BELOW_MINIMUM_MONTHS(726, "Thời gian thuê ngắn hơn số tháng tối thiểu của cơ sở", HttpStatus.BAD_REQUEST),
    OVERDUE_FEE_UNPAID_ON_RETURN(727, "Khách phải thanh toán phí trễ hạn trước khi hoàn tất nghiệm thu trả kho", HttpStatus.CONFLICT),
    CHECKIN_RENTAL_ENDED(728, "Thời hạn thuê đã kết thúc. Khách cần đặt kho mới trước khi nhận kho", HttpStatus.CONFLICT),
    UNIT_ASSIGNMENT_REQUIRED(733, "Quản lý cơ sở cần xác nhận ngăn kho cụ thể trước khi nhân viên bàn giao", HttpStatus.CONFLICT),
    HANDOVER_ASSIGNED_TO_ANOTHER_STAFF(729, "Lịch hẹn này đã được phân công cho nhân viên khác", HttpStatus.FORBIDDEN),
    GATE_PASS_INVALID(730, "Mã QR không hợp lệ hoặc thuộc cơ sở khác", HttpStatus.FORBIDDEN),
    GATE_PASS_EXPIRED(731, "Mã QR đã hết hạn. Vui lòng tạo mã mới.", HttpStatus.GONE),
    GATE_PASS_USED(732, "Mã QR đã được sử dụng hoặc đã bị thay thế", HttpStatus.CONFLICT),
    ADVANCE_RESERVATION_EXCEEDED(734, "Ngày bắt đầu vượt quá thời gian đặt trước tối đa của cơ sở", HttpStatus.BAD_REQUEST),
    TERMS_AND_CONDITIONS_REQUIRED(735, "Bạn cần đồng ý điều khoản thuê kho và cam kết không lưu trữ hàng cấm", HttpStatus.BAD_REQUEST),
    DAMAGE_FEE_EXCEEDS_DEPOSIT(736, "Phí hư hại không được vượt quá số tiền cọc đang giữ", HttpStatus.BAD_REQUEST),


    UNIT_UNAVAILABLE(
            709,
            "Ngăn kho không ở trạng thái phù hợp để thực hiện thao tác này",
            HttpStatus.CONFLICT
    ),

    UNIT_CODE_EXISTED(
            710,
            "Mã ngăn kho đã tồn tại tại cơ sở này",
            HttpStatus.CONFLICT
    ),
    // ========================= PAYMENT (750 - 799) =========================
    PAYMENT_NOT_FOUND(750, "Không tìm thấy giao dịch thanh toán", HttpStatus.NOT_FOUND),
    PAYMENT_ALREADY_PROCESSED(751, "Giao dịch đã được xử lý trước đó", HttpStatus.CONFLICT),
    PAYMENT_RECONCILIATION_PENDING(752, "Giao dịch VNPay trước đó đang được đối soát. Vui lòng thử lại sau ít phút.", HttpStatus.CONFLICT),

    // ========================= ROLE_PERMISSION (800 - 899) =========================
    ROLE_PERMISSION_NOT_FOUND(800, "Không tìm thấy phân quyền của vai trò", HttpStatus.NOT_FOUND),
    ROLE_PERMISSION_ALREADY_EXISTS(801, "Quyền này đã được gán cho vai trò", HttpStatus.BAD_REQUEST),

    // ========================= PERMISSION (900 - 999) =========================
    PERMISSION_NOT_FOUND(900, "Không tìm thấy quyền", HttpStatus.NOT_FOUND),
    PERMISSION_NAME_EXISTED(901, "Tên quyền đã tồn tại", HttpStatus.BAD_REQUEST),
    PERMISSION_GROUP_EXISTED(902, "Nhóm quyền đã tồn tại", HttpStatus.BAD_REQUEST),
    PERMISSION_IN_USE(903, "Không thể xóa quyền đang được gán cho vai trò", HttpStatus.CONFLICT),
    PERMISSION_INACTIVE(904, "Quyền đã bị vô hiệu hóa", HttpStatus.BAD_REQUEST),

    // ========================= FACILITY (1000 - 1099) =========================
    FACILITY_NOT_FOUND(1000, "Không tìm thấy cơ sở", HttpStatus.NOT_FOUND),
    FACILITY_CODE_EXISTED(1001, "Mã cơ sở đã tồn tại", HttpStatus.BAD_REQUEST),
    INVALID_MANAGER_TO_ASSIGN(1002,"Người được chọn không hợp lệ để làm quản lý cơ sở này",HttpStatus.BAD_REQUEST),
    FACILITY_NOT_ACTIVE(1003, "Cơ sở này hiện không nhận đặt kho mới", HttpStatus.CONFLICT),
    // ========================= FACILITY_POLICY (1100 - 1199) =========================
    FACILITY_POLICY_NOT_FOUND(1100, "Không tìm thấy chính sách của cơ sở", HttpStatus.NOT_FOUND),
    FACILITY_POLICY_ALREADY_EXISTS(1101, "Cơ sở này đã có chính sách", HttpStatus.BAD_REQUEST),
    FACILITY_POLICY_INVALID_CANCELLATION(1102, "Số giờ hoàn tiền toàn phần phải lớn hơn hoặc bằng số giờ hoàn tiền một phần", HttpStatus.BAD_REQUEST),

    // ========================= SUPPORT_TICKET (1200 - 1299) =========================
    TICKET_NOT_FOUND(1200, "Không tìm thấy yêu cầu hỗ trợ hoặc yêu cầu không thuộc về bạn", HttpStatus.NOT_FOUND),
    STAFF_HAS_UNCLOSED_TICKETS(1201, "Hãy chuyển giao hoặc đóng các yêu cầu hỗ trợ của nhân viên này trước khi gỡ khỏi cơ sở", HttpStatus.CONFLICT),

    // ========================= ACTIVITY_LOG (1300 - 1399) =========================
    ACTIVITY_LOG_NOT_FOUND(1300, "Không tìm thấy bản ghi nhật ký", HttpStatus.NOT_FOUND),

    // ========================= WAITLIST (1400 - 1499) =========================
    WAITLIST_ALREADY_JOINED(1400, "Bạn đã có trong danh sách chờ loại kho này tại cơ sở", HttpStatus.CONFLICT),
    WAITLIST_UNITS_AVAILABLE(1401, "Hiện còn ngăn kho trống, hãy đặt kho thay vì vào danh sách chờ", HttpStatus.CONFLICT);


    private final int code;
    private final String message;
    private final HttpStatus httpStatus;

    ErrorCode(int code, String message, HttpStatus httpStatus) {
        this.code = code;
        this.message = message;
        this.httpStatus = httpStatus;
    }
}
