import 'package:flutter/material.dart';

class RoleMeta {
  final String roleKey;
  final String viName;
  final IconData icon;
  final Color color;
  final String badge;
  final String summary;
  final String mainScreen;
  final String targetAudience;
  final List<String> defaultPermissions;
  final List<String> applicablePermissions;

  const RoleMeta({
    required this.roleKey,
    required this.viName,
    required this.icon,
    required this.color,
    required this.badge,
    required this.summary,
    required this.mainScreen,
    required this.targetAudience,
    required this.defaultPermissions,
    this.applicablePermissions = const [],
  });
}

class PermissionMeta {
  final String viTitle;
  final String explanation;
  final String effectWhenOn;
  final String effectWhenOff;
  final String groupViTitle;
  final IconData groupIcon;
  final bool isDangerous;

  const PermissionMeta({
    required this.viTitle,
    required this.explanation,
    required this.effectWhenOn,
    required this.effectWhenOff,
    required this.groupViTitle,
    required this.groupIcon,
    this.isDangerous = false,
  });
}

class RolePermissionHelper {
  const RolePermissionHelper._();

  static const Map<String, RoleMeta> roles = {
    'ADMIN': RoleMeta(
      roleKey: 'ADMIN',
      viName: 'Quản trị hệ thống',
      icon: Icons.admin_panel_settings_rounded,
      color: Color(0xFF7C3AED),
      badge: 'Cấp quản trị cao nhất',
      summary:
          'Toàn quyền quản trị hệ thống, quản lý tài khoản người dùng, phân quyền các Role, xem nhật ký kiểm toán Audit và cấu hình chi nhánh cơ sở.',
      mainScreen: 'Admin Dashboard (Tài khoản, Phân quyền, Nhật ký kiểm toán)',
      targetAudience: 'Dành riêng cho Quản trị viên kỹ thuật và Admin hệ thống.',
      defaultPermissions: [
        'USER_VIEW', 'USER_CREATE', 'USER_UPDATE', 'USER_DELETE',
        'ROLE_VIEW', 'ROLE_CREATE', 'ROLE_UPDATE', 'ROLE_DELETE',
        'PERMISSION_VIEW', 'PERMISSION_CREATE', 'PERMISSION_UPDATE', 'PERMISSION_DELETE',
        'ROLE_PERMISSION_VIEW', 'ROLE_PERMISSION_ASSIGN', 'ROLE_PERMISSION_REVOKE',
        'STAFF_ASSIGNMENT_CREATE', 'STAFF_ASSIGNMENT_VIEW',
        'ACTIVITY_LOG_VIEW', 'LOGIN_HISTORY_VIEW',
        'FACILITY_VIEW', 'POLICY_VIEW', 'PAYMENT_VIEW',
      ],
      applicablePermissions: [
        'USER_VIEW', 'USER_CREATE', 'USER_UPDATE', 'USER_DELETE',
        'ROLE_VIEW', 'ROLE_CREATE', 'ROLE_UPDATE', 'ROLE_DELETE',
        'PERMISSION_VIEW', 'PERMISSION_CREATE', 'PERMISSION_UPDATE', 'PERMISSION_DELETE',
        'ROLE_PERMISSION_VIEW', 'ROLE_PERMISSION_ASSIGN', 'ROLE_PERMISSION_REVOKE',
        'STAFF_ASSIGNMENT_VIEW', 'STAFF_ASSIGNMENT_CREATE', 'STAFF_ASSIGNMENT_DELETE',
        'ACTIVITY_LOG_VIEW', 'LOGIN_HISTORY_VIEW',
        'FACILITY_VIEW', 'POLICY_VIEW', 'PAYMENT_VIEW', 'REPORT_VIEW',
      ],
    ),
    'FACILITY_MANAGER': RoleMeta(
      roleKey: 'FACILITY_MANAGER',
      viName: 'Quản lý cơ sở',
      icon: Icons.storefront_rounded,
      color: Color(0xFF2563EB),
      badge: 'Quản lý chi nhánh kho',
      summary:
          'Chịu trách nhiệm vận hành chi nhánh kho (HCM-D1, HCM-D7...). Phân công nhân viên, gán ngăn kho cho khách, duyệt hoàn tiền cọc và điều phối ticket sự cố tại cơ sở.',
      mainScreen: 'Manager Dashboard (Gán ngăn & staff, Duyệt hoàn cọc, Quản lý kho)',
      targetAudience: 'Trưởng chi nhánh, Quản lý cơ sở kho mini.',
      defaultPermissions: [
        'REFUND_APPROVE',
        'BOOKING_UPDATE',
        'STAFF_ASSIGNMENT_CREATE',
        'STAFF_ASSIGNMENT_DELETE',
        'SUPPORT_UPDATE',
        'STORAGE_UNIT_CREATE',
        'STORAGE_UNIT_UPDATE',
        'ACCESS_CREDENTIAL_UPDATE',
        'REPORT_VIEW',
      ],
      applicablePermissions: [
        // Hoàn cọc sau trả kho (Chốt chặn tài chính quan trọng của Quản lý)
        'REFUND_APPROVE',
        // Đặt chỗ & Gán ngăn kho / Xử lý sự cố booking
        'BOOKING_UPDATE',
        // Phân công & Điều phối nhân viên chi nhánh
        'STAFF_ASSIGNMENT_CREATE',
        'STAFF_ASSIGNMENT_DELETE',
        // Xử lý sự cố / Điều phối ticket tại cơ sở
        'SUPPORT_UPDATE',
        // Quản lý ngăn kho cơ sở (thêm mới, đổi trạng thái)
        'STORAGE_UNIT_CREATE',
        'STORAGE_UNIT_UPDATE',
        // Khóa thông minh (Cấp lại PIN tại quầy cho khách)
        'ACCESS_CREDENTIAL_UPDATE',
        // Báo cáo & Thống kê lấp đầy cơ sở
        'REPORT_VIEW',
      ],
    ),
    'STAFF': RoleMeta(
      roleKey: 'STAFF',
      viName: 'Nhân viên cơ sở',
      icon: Icons.badge_rounded,
      color: Color(0xFFD97706),
      badge: 'Nhân sự trực tiếp tại kho',
      summary:
          'Nhân viên làm việc tại chi nhánh kho. Trực tiếp thực hiện bàn giao kho Check-in cho khách, quét mã QR vào cổng tại cổng kiểm soát, nghiệm thu trả kho Check-out và xử lý sự cố tại chỗ.',
      mainScreen: 'Staff Dashboard (Lịch Check-in/Check-out, Quét QR cổng, Xử lý ticket)',
      targetAudience: 'Nhân viên lễ tân, bảo vệ, kỹ thuật trực ca tại cơ sở.',
      defaultPermissions: [
        'HANDOVER_CREATE',
        'ACCESS_CREDENTIAL_VIEW',
        'ACCESS_CREDENTIAL_UPDATE',
        'SUPPORT_UPDATE',
        'STORAGE_UNIT_UPDATE',
      ],
      applicablePermissions: [
        // Bàn giao Check-in & Nghiệm thu Check-out trực tiếp
        'HANDOVER_CREATE',
        // Quét và xác thực mã QR vào cổng của khách
        'ACCESS_CREDENTIAL_VIEW',
        // Cấp lại mã PIN tại quầy cho khách quên
        'ACCESS_CREDENTIAL_UPDATE',
        // Tiếp nhận & Cập nhật xử lý ticket sự cố
        'SUPPORT_UPDATE',
        // Cập nhật trạng thái ngăn kho (bảo trì / sẵn sàng)
        'STORAGE_UNIT_UPDATE',
      ],
    ),
    'BUSINESS_MANAGER': RoleMeta(
      roleKey: 'BUSINESS_MANAGER',
      viName: 'Quản lý vận hành & kinh doanh',
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF0284C7),
      badge: 'Vận hành & Doanh thu',
      summary:
          'Theo dõi chỉ số kinh doanh toàn chuỗi: tỷ lệ lấp đầy ngăn kho, biểu đồ doanh thu theo cơ sở, điều chỉnh bảng giá niêm yết và chính sách thuê kho.',
      mainScreen: 'Operations Dashboard (Biểu đồ doanh thu, Bảng giá niêm yết, Chính sách)',
      targetAudience: 'Giám đốc Vận hành (COO), Giám đốc Kinh doanh.',
      defaultPermissions: [
        'REPORT_VIEW',
        'UNIT_TYPE_UPDATE',
        'POLICY_CREATE',
        'POLICY_UPDATE',
        'FACILITY_UPDATE',
      ],
      applicablePermissions: [
        // Báo cáo & Doanh thu toàn chuỗi
        'REPORT_VIEW',
        // Danh mục loại kho & Bảng giá niêm yết
        'UNIT_TYPE_UPDATE',
        // Thiết lập chính sách vận hành & Phí cọc
        'POLICY_CREATE',
        'POLICY_UPDATE',
        // Quản lý thông tin chi nhánh cơ sở
        'FACILITY_UPDATE',
      ],
    ),
    'CUSTOMER': RoleMeta(
      roleKey: 'CUSTOMER',
      viName: 'Khách hàng',
      icon: Icons.person_rounded,
      color: Color(0xFF10B981),
      badge: 'Người thuê kho tự quản',
      summary:
          'Khách hàng thuê kho tự quản 24/7. Tìm kiếm & đặt chỗ kho, thanh toán VNPay, tạo mã QR vào cổng, điều khiển Khóa thông minh PIN 6 số, gia hạn thuê hoặc yêu cầu trả kho.',
      mainScreen: 'Customer App (Khám phá kho, Kho của tôi, Khóa thông minh PIN 6 số)',
      targetAudience: 'Cá nhân, hộ gia đình hoặc doanh nghiệp thuê kho.',
      defaultPermissions: [
        'FACILITY_VIEW', 'UNIT_TYPE_VIEW', 'STORAGE_UNIT_VIEW',
        'BOOKING_VIEW', 'BOOKING_CREATE', 'BOOKING_CANCEL',
        'PAYMENT_VIEW', 'PAYMENT_CREATE',
        'ACCESS_CREDENTIAL_VIEW', 'ACCESS_CREDENTIAL_UPDATE',
        'CONTRACT_VIEW', 'CONTRACT_UPDATE',
        'RENEWAL_VIEW', 'RENEWAL_CREATE',
        'SUPPORT_VIEW', 'SUPPORT_CREATE',
      ],
      applicablePermissions: [
        // Đặt chỗ & Đơn thuê
        'BOOKING_VIEW', 'BOOKING_CREATE', 'BOOKING_CANCEL',
        // Khóa thông minh PIN 6 số & Cổng vào
        'ACCESS_CREDENTIAL_VIEW', 'ACCESS_CREDENTIAL_UPDATE',
        // Hợp đồng & Trả kho
        'CONTRACT_VIEW', 'CONTRACT_UPDATE',
        // Gia hạn hợp đồng
        'RENEWAL_VIEW', 'RENEWAL_CREATE',
        // Thanh toán trực tuyến (VNPay)
        'PAYMENT_VIEW', 'PAYMENT_CREATE',
        // Phiếu hỗ trợ sự cố
        'SUPPORT_VIEW', 'SUPPORT_CREATE',
        // Khám phá chi nhánh kho & loại kho
        'FACILITY_VIEW', 'UNIT_TYPE_VIEW', 'STORAGE_UNIT_VIEW',
      ],
    ),
  };

  static RoleMeta getRoleMeta(String? roleKey) {
    final clean = (roleKey ?? '').trim().toUpperCase().replaceAll('ROLE_', '');
    return roles[clean] ??
        RoleMeta(
          roleKey: clean,
          viName: clean,
          icon: Icons.security_rounded,
          color: Colors.blueGrey,
          badge: 'Vai trò tùy chỉnh',
          summary: 'Vai trò người dùng trong hệ thống StoreHub.',
          mainScreen: 'Giao diện tương ứng theo vai trò',
          targetAudience: 'Người dùng được phân công vai trò này.',
          defaultPermissions: const [],
        );
  }

  static const Map<String, PermissionMeta> permissions = {
    // 1. Khóa thông minh & Ra vào cổng
    'ACCESS_CREDENTIAL_VIEW': PermissionMeta(
      viTitle: 'Xem thông tin Khóa thông minh & mã PIN',
      explanation: 'Cho phép xem thông tin khóa số, trạng thái khóa/mở cửa của ngăn kho.',
      effectWhenOn: 'Hiển thị thẻ Khóa thông minh trong mục Kho của tôi.',
      effectWhenOff: 'Không thể xem trạng thái khóa thông minh.',
      groupViTitle: 'Khóa thông minh & Cổng vào',
      groupIcon: Icons.vpn_key_rounded,
    ),
    'ACCESS_CREDENTIAL_UPDATE': PermissionMeta(
      viTitle: 'Đổi / Đặt lại mã PIN Khóa thông minh',
      explanation: 'Cho phép khách hàng đổi mã PIN 6 số, hoặc quản lý đặt lại PIN khi khách quên.',
      effectWhenOn: 'Cho phép bấm nút Đổi PIN hoặc Cấp lại PIN 6 số.',
      effectWhenOff: 'Bị ẩn nút đổi mã PIN hoặc báo lỗi 403 Forbidden.',
      groupViTitle: 'Khóa thông minh & Cổng vào',
      groupIcon: Icons.vpn_key_rounded,
    ),

    // 2. Bàn giao Check-in & Nghiệm thu Check-out
    'HANDOVER_VIEW': PermissionMeta(
      viTitle: 'Xem biên bản bàn giao & nghiệm thu kho',
      explanation: 'Xem lịch sử và ảnh chụp biên bản bàn giao khi khách nhận hoặc trả kho.',
      effectWhenOn: 'Mở được danh sách biên bản bàn giao tại chi nhánh.',
      effectWhenOff: 'Bị chặn xem biên bản bàn giao.',
      groupViTitle: 'Bàn giao & Nghiệm thu kho',
      groupIcon: Icons.fact_check_rounded,
    ),
    'HANDOVER_CREATE': PermissionMeta(
      viTitle: 'Thực hiện ca Bàn giao Check-in & Nghiệm thu Check-out',
      explanation: 'Cho phép nhân viên bấm hoàn tất bàn giao kho hoặc bấm nghiệm thu trả kho.',
      effectWhenOn: 'Hiện nút Check-in và Nghiệm thu trong danh sách lịch hẹn của nhân viên.',
      effectWhenOff: 'Nhân viên không thể bấm Check-in hoặc nghiệm thu ngăn kho.',
      groupViTitle: 'Bàn giao & Nghiệm thu kho',
      groupIcon: Icons.fact_check_rounded,
    ),

    // 3. Hoàn tiền cọc & Thanh toán
    'REFUND_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách yêu cầu hoàn cọc',
      explanation: 'Xem danh sách các yêu cầu hoàn cọc chuyển khoản sau khi khách trả kho xong.',
      effectWhenOn: 'Truy cập được màn hình Duyệt hoàn tiền cọc.',
      effectWhenOff: 'Không thấy mục duyệt hoàn cọc.',
      groupViTitle: 'Hoàn tiền cọc & Thanh toán',
      groupIcon: Icons.monetization_on_rounded,
    ),
    'REFUND_APPROVE': PermissionMeta(
      viTitle: 'Duyệt chuyển khoản hoàn tiền cọc',
      explanation: 'Cho phép quản lý bấm Xác nhận chuyển khoản hoàn trả 500k-1tr tiền cọc cho khách.',
      effectWhenOn: 'Nút Duyệt chuyển khoản hoạt động bình thường, đổi trạng thái cọc sang Đã hoàn tất.',
      effectWhenOff: 'Bị chặn bấm nút duyệt hoàn cọc.',
      groupViTitle: 'Hoàn tiền cọc & Thanh toán',
      groupIcon: Icons.monetization_on_rounded,
      isDangerous: true,
    ),
    'PAYMENT_VIEW': PermissionMeta(
      viTitle: 'Xem lịch sử giao dịch thanh toán',
      explanation: 'Xem danh sách các đơn thanh toán tiền thuê, tiền cọc VNPay / Chuyển khoản.',
      effectWhenOn: 'Hiển thị mục Lịch sử thanh toán và hóa đơn điện tử.',
      effectWhenOff: 'Bị ẩn màn hình giao dịch thanh toán.',
      groupViTitle: 'Hoàn tiền cọc & Thanh toán',
      groupIcon: Icons.monetization_on_rounded,
    ),
    'PAYMENT_CREATE': PermissionMeta(
      viTitle: 'Tạo yêu cầu thanh toán (VNPay)',
      explanation: 'Khởi tạo link thanh toán tiền thuê hoặc tiền cọc qua cổng VNPay Sandbox.',
      effectWhenOn: 'Cho phép bấm nút Thanh toán ngay để mở cổng VNPay.',
      effectWhenOff: 'Không thể tạo phiên thanh toán mới.',
      groupViTitle: 'Hoàn tiền cọc & Thanh toán',
      groupIcon: Icons.monetization_on_rounded,
    ),

    // 4. Đơn thuê, Hợp đồng & Đặt chỗ
    'BOOKING_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách đơn thuê kho',
      explanation: 'Xem tất cả đơn đặt giữ chỗ, đơn đang thuê, đơn chờ thanh toán và lịch sử thuê kho.',
      effectWhenOn: 'Tải và xem được danh sách đơn thuê của cá nhân hoặc cơ sở.',
      effectWhenOff: 'Không tải được danh sách đơn thuê (Lỗi 403).',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'BOOKING_CREATE': PermissionMeta(
      viTitle: 'Tạo đơn đặt giữ chỗ thuê kho',
      explanation: 'Cho phép người dùng chọn kho và bấm Đặt giữ chỗ 30 phút.',
      effectWhenOn: 'Bấm nút Đặt kho và giữ chỗ thành công.',
      effectWhenOff: 'Không thể đặt kho mới.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'BOOKING_UPDATE': PermissionMeta(
      viTitle: 'Cập nhật đơn thuê & Gán ngăn kho',
      explanation: 'Cho phép quản lý cơ sở chọn ngăn kho và gán nhân viên phụ trách cho đơn đặt chỗ.',
      effectWhenOn: 'Cho phép Quản lý bấm nút Gán ngăn & nhân viên trong Booking Assignment.',
      effectWhenOff: 'Không thể gán ngăn hoặc sửa thông tin đơn thuê.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'BOOKING_CANCEL': PermissionMeta(
      viTitle: 'Hủy đơn đặt giữ chỗ',
      explanation: 'Cho phép hủy đơn đang chờ thanh toán hoặc đơn chưa check-in để giải phóng ngăn kho.',
      effectWhenOn: 'Hiển thị nút Hủy đơn cho người dùng/quản lý.',
      effectWhenOff: 'Không thể hủy đơn đặt chỗ.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'CONTRACT_VIEW': PermissionMeta(
      viTitle: 'Xem hợp đồng thuê kho điện tử',
      explanation: 'Xem các điều khoản và thông tin hợp đồng thuê kho.',
      effectWhenOn: 'Xem được chi tiết hợp đồng thuê kho.',
      effectWhenOff: 'Không xem được hợp đồng.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'CONTRACT_CREATE': PermissionMeta(
      viTitle: 'Lập hợp đồng thuê kho mới',
      explanation: 'Tự động tạo bản ghi hợp đồng khi khách hoàn tất thanh toán tiền cọc.',
      effectWhenOn: 'Hệ thống tự động phát hành hợp đồng thuê kho.',
      effectWhenOff: 'Bị chặn tạo hợp đồng.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'CONTRACT_UPDATE': PermissionMeta(
      viTitle: 'Cập nhật trạng thái hợp đồng',
      explanation: 'Cho phép sửa trạng thái hợp đồng sang Đã thanh lý hoặc Tạm dừng.',
      effectWhenOn: 'Cho phép chỉnh sửa hợp đồng.',
      effectWhenOff: 'Không thể cập nhật hợp đồng.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'RENEWAL_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách yêu cầu gia hạn thuê kho',
      explanation: 'Xem các yêu cầu gia hạn thêm tháng của khách hàng.',
      effectWhenOn: 'Xem được lịch sử và trạng thái gia hạn.',
      effectWhenOff: 'Không xem được danh sách gia hạn.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'RENEWAL_CREATE': PermissionMeta(
      viTitle: 'Tạo đơn gia hạn thời gian thuê',
      explanation: 'Cho phép khách hàng bấm Gia hạn thời gian thuê kho thêm 1, 3, 6 hoặc 12 tháng.',
      effectWhenOn: 'Hiện nút Gia hạn kho trong màn hình Kho của tôi.',
      effectWhenOff: 'Khách hàng không thể gia hạn kho qua app.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'OVERDUE_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách kho quá hạn thuê',
      explanation: 'Theo dõi các ngăn kho đã hết hạn hợp đồng nhưng khách chưa trả kho.',
      effectWhenOn: 'Hiển thị danh sách ngăn kho quá hạn trong Manager Dashboard.',
      effectWhenOff: 'Không xem được danh sách quá hạn.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
    ),
    'OVERDUE_PROCESS': PermissionMeta(
      viTitle: 'Kích hoạt xử lý / niêm phong kho quá hạn',
      explanation: 'Cho phép quản lý khóa tạm thời hoặc niêm phong kho quá hạn theo chính sách.',
      effectWhenOn: 'Cho phép bấm nút Niêm phong kho quá hạn.',
      effectWhenOff: 'Không có quyền xử lý kho quá hạn.',
      groupViTitle: 'Đơn thuê & Hợp đồng',
      groupIcon: Icons.receipt_long_rounded,
      isDangerous: true,
    ),

    // 5. Cơ sở kho & Ngăn chứa
    'STORAGE_UNIT_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách & sơ đồ ngăn kho',
      explanation: 'Xem danh sách các ngăn chứa (S-101, M-201...), diện tích và trạng thái (Trống, Đang thuê...).',
      effectWhenOn: 'Hiển thị sơ đồ ngăn kho tại cơ sở.',
      effectWhenOff: 'Không thể tải danh sách ngăn kho.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
    ),
    'STORAGE_UNIT_CREATE': PermissionMeta(
      viTitle: 'Thêm ngăn kho mới',
      explanation: 'Cho phép tạo thêm ngăn kho mới vào cơ sở.',
      effectWhenOn: 'Hiện nút Thêm ngăn kho.',
      effectWhenOff: 'Không thể thêm ngăn kho mới.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
    ),
    'STORAGE_UNIT_UPDATE': PermissionMeta(
      viTitle: 'Sửa thông tin & trạng thái ngăn kho (L-301, M-201...)',
      explanation: 'Cho phép bấm icon cây bút trên từng ngăn kho để sửa mã ngăn, số tầng, loại kho hoặc đổi trạng thái bảo trì / trống.',
      effectWhenOn: 'Cho phép bấm icon cây bút để sửa thông tin ngăn kho trong bảng điều khiển cơ sở.',
      effectWhenOff: 'Bị chặn khi lưu thay đổi ngăn kho (Lỗi 403 Forbidden).',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
    ),
    'STORAGE_UNIT_DELETE': PermissionMeta(
      viTitle: 'Xóa ngăn kho',
      explanation: 'Xóa vĩnh viễn ngăn kho khỏi hệ thống.',
      effectWhenOn: 'Cho phép xóa ngăn kho (chỉ xóa được khi ngăn trống và không có hợp đồng).',
      effectWhenOff: 'Không thể xóa ngăn kho.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
      isDangerous: true,
    ),
    'UNIT_TYPE_VIEW': PermissionMeta(
      viTitle: 'Xem danh mục loại kích thước kho',
      explanation: 'Xem danh sách các loại kích thước kho (Small, Medium, Large, Extra Large).',
      effectWhenOn: 'Hiển thị danh mục loại kho trên app.',
      effectWhenOff: 'Không xem được loại kho.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
    ),
    'UNIT_TYPE_CREATE': PermissionMeta(
      viTitle: 'Tạo loại kích thước kho mới',
      explanation: 'Tạo thêm gói kích thước kho mới (diện tích, thể tích, giá niêm yết).',
      effectWhenOn: 'Cho phép thêm loại kho mới.',
      effectWhenOff: 'Không thể tạo loại kho.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
    ),
    'UNIT_TYPE_UPDATE': PermissionMeta(
      viTitle: 'Sửa thông số loại kích thước kho',
      explanation: 'Sửa diện tích, thể tích, tải trọng và giá niêm yết của loại kho.',
      effectWhenOn: 'Cho phép cập nhật loại kho.',
      effectWhenOff: 'Không thể sửa loại kho.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
    ),
    'UNIT_TYPE_DELETE': PermissionMeta(
      viTitle: 'Xóa loại kích thước kho',
      explanation: 'Xóa gói loại kho khỏi hệ thống.',
      effectWhenOn: 'Cho phép xóa loại kho.',
      effectWhenOff: 'Không thể xóa loại kho.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
      isDangerous: true,
    ),
    'FACILITY_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách chi nhánh cơ sở kho',
      explanation: 'Xem danh sách các chi nhánh cơ sở kho (HCM-D1, HCM-D7, HCM-TD...).',
      effectWhenOn: 'Tải và xem được danh sách cơ sở kho trên bản đồ và danh sách.',
      effectWhenOff: 'Không thể tải danh sách cơ sở.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
    ),
    'FACILITY_CREATE': PermissionMeta(
      viTitle: 'Thêm cơ sở chi nhánh mới',
      explanation: 'Tạo thêm chi nhánh kho mới vào hệ thống.',
      effectWhenOn: 'Cho phép tạo cơ sở mới.',
      effectWhenOff: 'Không thể tạo cơ sở.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
    ),
    'FACILITY_UPDATE': PermissionMeta(
      viTitle: 'Sửa thông tin cơ sở kho',
      explanation: 'Sửa tên chi nhánh, địa chỉ, hotline, giờ mở cửa, tiện ích và ảnh cơ sở.',
      effectWhenOn: 'Cho phép cập nhật thông tin chi nhánh.',
      effectWhenOff: 'Không thể sửa thông tin chi nhánh.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
    ),
    'FACILITY_DELETE': PermissionMeta(
      viTitle: 'Xóa / đóng cửa cơ sở kho',
      explanation: 'Xóa chi nhánh kho khỏi hệ thống.',
      effectWhenOn: 'Cho phép xóa chi nhánh.',
      effectWhenOff: 'Không thể xóa chi nhánh.',
      groupViTitle: 'Cơ sở kho & Ngăn chứa',
      groupIcon: Icons.warehouse_rounded,
      isDangerous: true,
    ),

    // 6. Quản lý & Phân công nhân viên
    'STAFF_ASSIGNMENT_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách nhân viên theo cơ sở',
      explanation: 'Xem danh sách nhân viên đang được phân công làm việc tại từng chi nhánh kho.',
      effectWhenOn: 'Hiển thị danh sách nhân sự của cơ sở.',
      effectWhenOff: 'Không thể xem phân công nhân sự.',
      groupViTitle: 'Phân công nhân sự',
      groupIcon: Icons.assignment_ind_rounded,
    ),
    'STAFF_ASSIGNMENT_CREATE': PermissionMeta(
      viTitle: 'Phân công nhân viên vào cơ sở',
      explanation: 'Cho phép Quản lý hoặc Admin gán nhân viên vào chi nhánh làm việc.',
      effectWhenOn: 'Cho phép gán nhân viên vào chi nhánh.',
      effectWhenOff: 'Không thể phân công nhân viên.',
      groupViTitle: 'Phân công nhân sự',
      groupIcon: Icons.assignment_ind_rounded,
    ),
    'STAFF_ASSIGNMENT_DELETE': PermissionMeta(
      viTitle: 'Hủy phân công nhân viên khỏi cơ sở',
      explanation: 'Rút nhân viên khỏi chi nhánh để phân công sang chi nhánh khác.',
      effectWhenOn: 'Cho phép gỡ nhân viên khỏi cơ sở.',
      effectWhenOff: 'Không thể hủy phân công nhân viên.',
      groupViTitle: 'Phân công nhân sự',
      groupIcon: Icons.assignment_ind_rounded,
    ),

    // 7. Tài khoản người dùng & Phân quyền
    'USER_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách tài khoản người dùng',
      explanation: 'Xem danh sách, tìm kiếm người dùng theo họ tên, email, số điện thoại.',
      effectWhenOn: 'Truy cập được màn hình Quản lý người dùng.',
      effectWhenOff: 'Không thể xem danh sách tài khoản (Lỗi 403).',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'USER_CREATE': PermissionMeta(
      viTitle: 'Tạo tài khoản người dùng mới',
      explanation: 'Cho phép tạo tài khoản thủ công (ví dụ tạo tài khoản nhân viên hoặc quản lý).',
      effectWhenOn: 'Hiện nút Thêm người dùng trong màn hình quản trị.',
      effectWhenOff: 'Không thể tạo tài khoản thủ công.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'USER_UPDATE': PermissionMeta(
      viTitle: 'Chỉnh sửa tài khoản & Phân vai trò',
      explanation: 'Cho phép đổi số điện thoại, đổi vai trò (Role), hoặc khóa/mở khóa tài khoản.',
      effectWhenOn: 'Cho phép lưu thông tin cập nhật tài khoản và gán vai trò mới.',
      effectWhenOff: 'Không thể sửa thông tin người dùng.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'USER_DELETE': PermissionMeta(
      viTitle: 'Xóa tài khoản người dùng',
      explanation: 'Xóa hoặc vô hiệu hóa vĩnh viễn tài khoản khỏi hệ thống.',
      effectWhenOn: 'Cho phép xóa tài khoản.',
      effectWhenOff: 'Không thể xóa tài khoản.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
      isDangerous: true,
    ),
    'ROLE_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách vai trò người dùng',
      explanation: 'Xem các vai trò trong hệ thống (Admin, Quản lý, Nhân viên, Vận hành, Khách hàng).',
      effectWhenOn: 'Truy cập được màn hình Vai trò & quyền hạn.',
      effectWhenOff: 'Không thể xem danh sách vai trò.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'ROLE_CREATE': PermissionMeta(
      viTitle: 'Tạo vai trò mới',
      explanation: 'Định nghĩa thêm một nhóm vai trò người dùng mới.',
      effectWhenOn: 'Cho phép tạo vai trò mới.',
      effectWhenOff: 'Không thể tạo vai trò.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'ROLE_UPDATE': PermissionMeta(
      viTitle: 'Cập nhật vai trò & mô tả',
      explanation: 'Chỉnh sửa mô tả và thông tin của vai trò.',
      effectWhenOn: 'Cho phép lưu sửa đổi vai trò.',
      effectWhenOff: 'Không thể sửa vai trò.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'ROLE_DELETE': PermissionMeta(
      viTitle: 'Xóa vai trò',
      explanation: 'Xóa vai trò khỏi hệ thống (chỉ xóa được khi không có người dùng nào giữ vai trò này).',
      effectWhenOn: 'Cho phép xóa vai trò.',
      effectWhenOff: 'Không thể xóa vai trò.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
      isDangerous: true,
    ),
    'ROLE_PERMISSION_VIEW': PermissionMeta(
      viTitle: 'Xem ma trận quyền của vai trò',
      explanation: 'Xem danh sách các quyền hạn được gán cho từng vai trò.',
      effectWhenOn: 'Hiển thị danh sách quyền chi tiết của vai trò được chọn.',
      effectWhenOff: 'Không thể xem quyền của vai trò.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'ROLE_PERMISSION_ASSIGN': PermissionMeta(
      viTitle: 'Cấp quyền cho vai trò',
      explanation: 'Tích bật quyền mới cho vai trò và lưu thay đổi.',
      effectWhenOn: 'Cho phép lưu quyền mới được tích.',
      effectWhenOff: 'Không thể cấp thêm quyền.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'ROLE_PERMISSION_REVOKE': PermissionMeta(
      viTitle: 'Thu hồi quyền khỏi vai trò',
      explanation: 'Bỏ tích và thu hồi quyền đã cấp cho vai trò.',
      effectWhenOn: 'Cho phép thu hồi quyền khi bỏ tích.',
      effectWhenOff: 'Không thể thu hồi quyền.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'PERMISSION_VIEW': PermissionMeta(
      viTitle: 'Xem danh mục quyền hệ thống',
      explanation: 'Xem toàn bộ 64 quyền hạn được định nghĩa trong mã nguồn StoreHub.',
      effectWhenOn: 'Tải được danh sách quyền hệ thống.',
      effectWhenOff: 'Không thể tải danh mục quyền.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'PERMISSION_CREATE': PermissionMeta(
      viTitle: 'Khởi tạo quyền hệ thống mới',
      explanation: 'Tạo thêm mã quyền hạn mới trong cơ sở dữ liệu.',
      effectWhenOn: 'Cho phép tạo quyền mới.',
      effectWhenOff: 'Không thể tạo quyền mới.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'PERMISSION_UPDATE': PermissionMeta(
      viTitle: 'Sửa mô tả quyền hệ thống',
      explanation: 'Cập nhật nội dung mô tả của quyền hạn.',
      effectWhenOn: 'Cho phép sửa mô tả quyền.',
      effectWhenOff: 'Không thể sửa mô tả quyền.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
    ),
    'PERMISSION_DELETE': PermissionMeta(
      viTitle: 'Xóa quyền khỏi hệ thống',
      explanation: 'Xóa mã quyền khỏi danh mục hệ thống.',
      effectWhenOn: 'Cho phép xóa quyền.',
      effectWhenOff: 'Không thể xóa quyền.',
      groupViTitle: 'Tài khoản & Phân quyền',
      groupIcon: Icons.people_alt_rounded,
      isDangerous: true,
    ),

    // 8. Báo cáo doanh thu & Nhật ký kiểm toán
    'REPORT_VIEW': PermissionMeta(
      viTitle: 'Xem báo cáo doanh thu & tỷ lệ lấp đầy',
      explanation: 'Xem biểu đồ thống kê tài chính, doanh thu theo cơ sở và tỷ lệ sử dụng kho.',
      effectWhenOn: 'Hiển thị toàn bộ biểu đồ và báo cáo trong Operations Dashboard.',
      effectWhenOff: 'Không thể xem báo cáo kinh doanh.',
      groupViTitle: 'Báo cáo & Kiểm toán',
      groupIcon: Icons.analytics_rounded,
    ),
    'ACTIVITY_LOG_VIEW': PermissionMeta(
      viTitle: 'Xem nhật ký kiểm toán hệ thống (Audit Logs)',
      explanation: 'Xem toàn bộ lịch sử ai đã đăng nhập, đổi quyền, duyệt cọc, sửa giá, gán ngăn.',
      effectWhenOn: 'Truy cập được màn hình Nhật ký hoạt động trong Admin Dashboard.',
      effectWhenOff: 'Không thể xem nhật ký kiểm toán.',
      groupViTitle: 'Báo cáo & Kiểm toán',
      groupIcon: Icons.analytics_rounded,
    ),
    'LOGIN_HISTORY_VIEW': PermissionMeta(
      viTitle: 'Xem lịch sử đăng nhập',
      explanation: 'Theo dõi thời gian đăng nhập, địa chỉ IP và trình duyệt của người dùng.',
      effectWhenOn: 'Xem được bảng lịch sử đăng nhập.',
      effectWhenOff: 'Không xem được lịch sử đăng nhập.',
      groupViTitle: 'Báo cáo & Kiểm toán',
      groupIcon: Icons.analytics_rounded,
    ),

    // 9. Bảng giá, Giảm giá & Chính sách
    'DISCOUNT_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách mã giảm giá (Voucher)',
      explanation: 'Xem các chương trình khuyến mãi giảm giá thuê kho đang áp dụng.',
      effectWhenOn: 'Hiển thị danh sách mã giảm giá.',
      effectWhenOff: 'Không xem được danh sách mã giảm giá.',
      groupViTitle: 'Bảng giá & Chính sách',
      groupIcon: Icons.loyalty_rounded,
    ),
    'DISCOUNT_CREATE': PermissionMeta(
      viTitle: 'Tạo mã giảm giá mới',
      explanation: 'Cho phép tạo mã voucher giảm phần trăm hoặc giảm tiền trực tiếp.',
      effectWhenOn: 'Hiện nút Tạo mã giảm giá.',
      effectWhenOff: 'Không thể tạo mã giảm giá.',
      groupViTitle: 'Bảng giá & Chính sách',
      groupIcon: Icons.loyalty_rounded,
    ),
    'DISCOUNT_UPDATE': PermissionMeta(
      viTitle: 'Chỉnh sửa mã giảm giá',
      explanation: 'Đổi phần trăm giảm, giá trị đơn tối thiểu hoặc ngày hết hạn voucher.',
      effectWhenOn: 'Cho phép cập nhật mã giảm giá.',
      effectWhenOff: 'Không thể sửa mã giảm giá.',
      groupViTitle: 'Bảng giá & Chính sách',
      groupIcon: Icons.loyalty_rounded,
    ),
    'DISCOUNT_DELETE': PermissionMeta(
      viTitle: 'Xóa mã giảm giá',
      explanation: 'Hủy bỏ mã voucher khỏi hệ thống.',
      effectWhenOn: 'Cho phép xóa mã giảm giá.',
      effectWhenOff: 'Không thể xóa mã giảm giá.',
      groupViTitle: 'Bảng giá & Chính sách',
      groupIcon: Icons.loyalty_rounded,
    ),
    'POLICY_VIEW': PermissionMeta(
      viTitle: 'Xem chính sách & quy định cơ sở',
      explanation: 'Xem nội quy cơ sở, chính sách hoàn hủy cọc và giờ giấc hoạt động.',
      effectWhenOn: 'Xem được danh sách chính sách cơ sở.',
      effectWhenOff: 'Không thể xem chính sách.',
      groupViTitle: 'Bảng giá & Chính sách',
      groupIcon: Icons.loyalty_rounded,
    ),
    'POLICY_CREATE': PermissionMeta(
      viTitle: 'Ban hành chính sách quy định mới',
      explanation: 'Thêm điều khoản quy định mới cho cơ sở kho.',
      effectWhenOn: 'Cho phép tạo chính sách mới.',
      effectWhenOff: 'Không thể tạo chính sách.',
      groupViTitle: 'Bảng giá & Chính sách',
      groupIcon: Icons.loyalty_rounded,
    ),
    'POLICY_UPDATE': PermissionMeta(
      viTitle: 'Cập nhật chính sách quy định',
      explanation: 'Sửa nội dung điều khoản, mức phạt quá hạn hoặc quy định gửi đồ.',
      effectWhenOn: 'Cho phép cập nhật chính sách.',
      effectWhenOff: 'Không thể cập nhật chính sách.',
      groupViTitle: 'Bảng giá & Chính sách',
      groupIcon: Icons.loyalty_rounded,
    ),
    'POLICY_DELETE': PermissionMeta(
      viTitle: 'Xóa chính sách quy định',
      explanation: 'Gỡ bỏ điều khoản chính sách.',
      effectWhenOn: 'Cho phép xóa chính sách.',
      effectWhenOff: 'Không thể xóa chính sách.',
      groupViTitle: 'Bảng giá & Chính sách',
      groupIcon: Icons.loyalty_rounded,
    ),

    // 10. Hỗ trợ khách hàng & Sự cố
    'SUPPORT_VIEW': PermissionMeta(
      viTitle: 'Xem danh sách phiếu hỗ trợ (Ticket)',
      explanation: 'Xem tất cả các yêu cầu hỗ trợ, báo hỏng khóa, kẹt cửa hoặc sự cố của khách.',
      effectWhenOn: 'Truy cập được màn hình Ticket hỗ trợ.',
      effectWhenOff: 'Không thể xem phiếu hỗ trợ.',
      groupViTitle: 'Hỗ trợ khách hàng & Sự cố',
      groupIcon: Icons.support_agent_rounded,
    ),
    'SUPPORT_CREATE': PermissionMeta(
      viTitle: 'Gửi yêu cầu hỗ trợ mới',
      explanation: 'Cho phép khách hàng tạo phiếu báo sự cố gửi tới ban quản lý cơ sở.',
      effectWhenOn: 'Hiện nút Gửi yêu cầu hỗ trợ.',
      effectWhenOff: 'Không thể tạo phiếu hỗ trợ mới.',
      groupViTitle: 'Hỗ trợ khách hàng & Sự cố',
      groupIcon: Icons.support_agent_rounded,
    ),
    'SUPPORT_UPDATE': PermissionMeta(
      viTitle: 'Tiếp nhận & Cập nhật phiếu hỗ trợ',
      explanation: 'Cho phép nhân viên nhận xử lý (Assign to me) hoặc đổi trạng thái Đã xử lý (Resolved).',
      effectWhenOn: 'Nhân viên và Quản lý có thể cập nhật trạng thái và ghi chú xử lý.',
      effectWhenOff: 'Không thể đổi trạng thái phiếu hỗ trợ.',
      groupViTitle: 'Hỗ trợ khách hàng & Sự cố',
      groupIcon: Icons.support_agent_rounded,
    ),
  };

  static PermissionMeta getPermissionMeta(String code, [String? rawGroup, String? rawDesc]) {
    final clean = code.trim().toUpperCase();
    if (permissions.containsKey(clean)) {
      return permissions[clean]!;
    }
    // Fallback nếu có quyền mới được thêm sau này
    final groupName = (rawGroup != null && rawGroup.isNotEmpty) ? rawGroup : 'Chức năng khác';
    return PermissionMeta(
      viTitle: clean.replaceAll('_', ' '),
      explanation: (rawDesc != null && rawDesc.isNotEmpty) ? rawDesc : 'Quyền thao tác hệ thống StoreHub.',
      effectWhenOn: 'Cho phép thực hiện thao tác $clean.',
      effectWhenOff: 'Bị từ chối thực hiện thao tác $clean (Lỗi 403 Forbidden).',
      groupViTitle: groupName,
      groupIcon: Icons.extension_rounded,
    );
  }
}
