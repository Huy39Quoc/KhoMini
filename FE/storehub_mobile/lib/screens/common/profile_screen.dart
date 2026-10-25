import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_api_service.dart';
import '../../widgets/logout_dialog.dart';
import '../auth/login_screen.dart';
import 'transaction_history_screen.dart';

const Map<String, String> _kRoleLabels = {
  'ADMIN': 'Quản trị hệ thống',
  'BUSINESS_MANAGER': 'Quản lý vận hành',
  'FACILITY_MANAGER': 'Quản lý cơ sở',
  'STAFF': 'Nhân viên cơ sở',
  'CUSTOMER': 'Khách hàng thuê kho',
};

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final String? facilityId;
  const ProfileScreen({super.key, required this.user, this.facilityId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthApiService _authApiService = AuthApiService();
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  bool _isLoggingOut = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _authApiService.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) return;
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await confirmLogout(context);
    if (!confirm) return;

    setState(() => _isLoggingOut = true);
    await _authApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final roleLabel =
        _kRoleLabels[user.roleName.toUpperCase()] ?? user.roleName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ tài khoản'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar & Role Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _initials(user.fullName.isNotEmpty
                            ? user.fullName
                            : user.username),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.fullName.isNotEmpty ? user.fullName : user.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      roleLabel,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account Information Group
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  _infoTile(Icons.mail_outline_rounded, 'Email', user.email),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.outlineVariant.withValues(alpha: 0.6),
                    indent: 56,
                  ),
                  _infoTile(Icons.badge_outlined, 'Tên đăng nhập', user.username),
                  if (user.phone.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.outlineVariant.withValues(alpha: 0.6),
                      indent: 56,
                    ),
                    _infoTile(
                        Icons.phone_outlined, 'Số điện thoại', user.phone),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Transaction History Shortcut
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primaryContainer,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Lịch sử giao dịch',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: const Text(
                  'Xem lịch sử giao dịch & biên lai thanh toán',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.outline, size: 20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransactionHistoryScreen(
                        userRole: user.roleName,
                        facilityId: widget.facilityId,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Change Password Section
            const Text(
              'Đổi mật khẩu',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: _obscureOld,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu hiện tại',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureOld
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscureOld = !_obscureOld),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Vui lòng nhập mật khẩu hiện tại'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu mới',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                        helperText: 'Tối thiểu 5 ký tự',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Vui lòng nhập mật khẩu mới';
                        }
                        if (v.length < 5) {
                          return 'Mật khẩu tối thiểu 5 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu mới',
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Vui lòng xác nhận mật khẩu mới';
                        }
                        if (v != _newPasswordController.text) {
                          return 'Mật khẩu xác nhận không khớp';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleChangePassword,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Cập nhật mật khẩu'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Logout Action
            ElevatedButton.icon(
              onPressed: _isLoggingOut ? null : _handleLogout,
              icon: _isLoggingOut
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                      ),
                    )
                  : const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Đăng xuất tài khoản'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorContainer,
                foregroundColor: AppColors.error,
                disabledBackgroundColor: AppColors.errorContainer,
                disabledForegroundColor: AppColors.error,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      subtitle: Text(
        value.isNotEmpty ? value : '-',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
