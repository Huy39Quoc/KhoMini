import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_api_service.dart';
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
          content: Text('Đổi mật khẩu thành công'),
          backgroundColor: AppColors.success,
        ),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập lại để tiếp tục.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

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
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Hồ sơ của tôi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.secondaryContainer,
                    child: Text(
                      _initials(user.fullName.isNotEmpty
                          ? user.fullName
                          : user.username),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.fullName.isNotEmpty ? user.fullName : user.username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(roleLabel,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _infoTile(Icons.email_outlined, 'Email', user.email),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _infoTile(Icons.account_circle_outlined, 'Tên đăng nhập',
                        user.username),
                    if (user.phone.isNotEmpty) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _infoTile(Icons.phone_outlined, 'Số điện thoại', user.phone),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primaryContainer),
                title: const Text('Lịch sử giao dịch',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Xem lịch sử giao dịch & biên lai',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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

            const Text('Đổi mật khẩu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureOld
                                ? Icons.visibility_off
                                : Icons.visibility),
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
                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility),
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
                          prefixIcon: const Icon(Icons.check_circle_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility),
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
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Cập nhật mật khẩu'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _isLoggingOut ? null : _handleLogout,
              icon: _isLoggingOut
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Đăng xuất',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.onSurfaceVariant),
      title: Text(label,
          style:
              const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
      subtitle: Text(value.isNotEmpty ? value : '-',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}
