/// Nhãn tiếng Việt cho các giá trị enum do máy chủ trả về.
class ViLabels {
  const ViLabels._();

  static String _norm(String? v) => (v ?? '').trim().toUpperCase();

  static String booking(String? status) {
    switch (_norm(status)) {
      case 'PENDING_PAYMENT':
        return 'Chờ thanh toán';
      case 'CONFIRMED':
        return 'Chờ nhận kho';
      case 'ACTIVE':
        return 'Đang thuê';
      case 'COMPLETED':
        return 'Đã trả kho';
      case 'CANCELLED':
        return 'Đã hủy';
      case 'OVERDUE':
        return 'Quá hạn';
      default:
        return status ?? '';
    }
  }

  static String unit(String? status) {
    switch (_norm(status)) {
      case 'AVAILABLE':
        return 'Trống';
      case 'RESERVED':
        return 'Đã giữ chỗ';
      case 'OCCUPIED':
        return 'Đang thuê';
      case 'UNDER_MAINTENANCE':
        return 'Cần kiểm tra / bảo trì';
      default:
        return status ?? '';
    }
  }

  static String ticketStatus(String? status) {
    switch (_norm(status)) {
      case 'OPEN':
        return 'Mới';
      case 'IN_PROGRESS':
        return 'Đang xử lý';
      case 'RESOLVED':
        return 'Đã xử lý';
      case 'CLOSED':
        return 'Đã đóng';
      default:
        return status ?? '';
    }
  }

  static String priority(String? value) {
    switch (_norm(value)) {
      case 'LOW':
        return 'Thấp';
      case 'MEDIUM':
        return 'Trung bình';
      case 'HIGH':
        return 'Cao';
      case 'URGENT':
        return 'Khẩn cấp';
      default:
        return value ?? '';
    }
  }

  static String ticketCategory(String? value) {
    switch (_norm(value)) {
      case 'PIN_CODE':
        return 'Sự cố mã PIN';
      case 'LOCK_ISSUE':
        return 'Sự cố khóa / cửa';
      case 'FACILITY_DAMAGE':
        return 'Hư hỏng cơ sở';
      case 'PAYMENT_ISSUE':
        return 'Sự cố thanh toán';
      case 'OTHER':
        return 'Khác';
      default:
        return value ?? '';
    }
  }

  static String waitlist(String? status) {
    switch (_norm(status)) {
      case 'WAITING':
        return 'Đang chờ';
      case 'NOTIFIED':
        return 'Đã có chỗ trống';
      case 'FULFILLED':
        return 'Đã đặt kho';
      case 'EXPIRED':
        return 'Hết hạn';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return status ?? '';
    }
  }

  static String refund(String? status) {
    switch (_norm(status)) {
      case 'QUEUED':
        return 'Đang chờ gửi hoàn tiền';
      case 'SENDING':
        return 'Đang gửi hoàn tiền';
      case 'AWAITING_CONFIRMATION':
        return 'Chờ VNPay xác nhận';
      case 'AWAITING_BANK_TRANSFER':
        return 'Chờ quản lý chuyển khoản';
      case 'COMPLETED':
        return 'Đã hoàn tất';
      case 'MISSING_METADATA':
        return 'Thiếu thông tin giao dịch gốc';
      case 'REJECTED':
        return 'Bị từ chối';
      case 'NEEDS_REVIEW':
        return 'Cần kiểm tra';
      default:
        return status ?? '';
    }
  }

  static String recordType(String? type) {
    switch (_norm(type)) {
      case 'CHECK_IN':
        return 'Bàn giao kho';
      case 'CHECK_IN_REJECTED':
        return 'Từ chối bàn giao (ngăn/khóa chưa đạt)';
      case 'CHECK_OUT':
      case 'RETURN':
        return 'Nghiệm thu trả kho';
      default:
        return type ?? '';
    }
  }

  static String role(String? role) {
    switch (_norm(role).replaceAll('ROLE_', '')) {
      case 'ADMIN':
      case 'SYSTEM_ADMIN':
        return 'Quản trị hệ thống';
      case 'BUSINESS_MANAGER':
      case 'BUSINESS_OPERATIONS_MANAGER':
      case 'OPERATIONS_MANAGER':
        return 'Quản lý vận hành';
      case 'FACILITY_MANAGER':
        return 'Quản lý cơ sở';
      case 'STAFF':
      case 'FACILITY_STAFF':
        return 'Nhân viên cơ sở';
      case 'CUSTOMER':
        return 'Khách hàng';
      default:
        return role ?? '';
    }
  }
}
