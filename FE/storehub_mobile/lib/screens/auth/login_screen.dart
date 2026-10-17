import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/http_client.dart';
import '../../models/user_model.dart';
import '../../services/auth_api_service.dart';
import '../common/role_dispatch_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialResetToken;

  const LoginScreen({super.key, this.initialResetToken});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authApiService = AuthApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialResetToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showResetPasswordDialog(widget.initialResetToken);
      });
    }
  }

  bool _isNetworkError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('timeout') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('10.0.2.2') ||
        lower.contains('network') ||
        lower.contains('failed');
  }

  void _showServerConfigDialog() {
    final customController = TextEditingController(text: ApiEndpoints.baseUrl);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dns_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Cài đặt địa chỉ máy chủ (API)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Hiện tại: ${ApiEndpoints.baseUrl}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn cấu hình phù hợp với thiết bị của bạn:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (!const bool.fromEnvironment('dart.vm.product')) ...[
              _serverOptionTile(
                ctx,
                title: '📱 Máy thật Android (qua cáp USB)',
                subtitle:
                    'http://127.0.0.1:8080/api/v1 (Khuyên dùng khi cắm cáp)',
                url: 'http://127.0.0.1:8080/api/v1',
              ),
              _serverOptionTile(
                ctx,
                title: '📶 Máy thật Android (qua Wi-Fi)',
                subtitle: 'http://192.168.101.6:8080/api/v1 (Cùng mạng Wi-Fi)',
                url: 'http://192.168.101.6:8080/api/v1',
              ),
              _serverOptionTile(
                ctx,
                title: '💻 Máy ảo Android Studio (Emulator)',
                subtitle: 'http://10.0.2.2:8080/api/v1',
                url: 'http://10.0.2.2:8080/api/v1',
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: customController,
              decoration: const InputDecoration(
                labelText: 'Hoặc tự nhập URL API của máy tính',
                hintText: bool.fromEnvironment('dart.vm.product')
                    ? 'https://api.example.com/api/v1'
                    : 'http://192.168.x.x:8080/api/v1',
                suffixIcon: Icon(Icons.edit_outlined),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (await _applyServerUrl(customController.text.trim()) &&
                      ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Lưu & Áp dụng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serverOptionTile(BuildContext ctx,
      {required String title, required String subtitle, required String url}) {
    final isSelected = ApiEndpoints.baseUrl == url;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
          : const Icon(Icons.chevron_right, size: 18),
      onTap: () async {
        if (await _applyServerUrl(url) && ctx.mounted) {
          Navigator.pop(ctx);
        }
      },
    );
  }

  Future<bool> _applyServerUrl(String newUrl) async {
    try {
      HttpClient.instance.updateBaseUrl(newUrl);
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message.toString())),
        );
      }
      return false;
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message.toString())),
        );
      }
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_api_base_url', ApiEndpoints.baseUrl);
    if (!mounted) return true;
    setState(() {
      _errorMessage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã đổi địa chỉ máy chủ thành: ${ApiEndpoints.baseUrl}'),
        backgroundColor: AppColors.success,
      ),
    );
    return true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final res = await _authApiService.login(email, password);

      if (!mounted) return;

      Map<String, dynamic>? userMap;
      if (res['user'] is Map<String, dynamic>) {
        userMap = res['user'] as Map<String, dynamic>;
      } else if (res['data'] is Map<String, dynamic> &&
          res['data']['user'] is Map<String, dynamic>) {
        userMap = res['data']['user'] as Map<String, dynamic>;
      } else if (res['data'] is Map<String, dynamic>) {
        userMap = res['data'] as Map<String, dynamic>;
      }

      if (userMap != null) {
        final user = UserModel.fromJson(userMap);
        if (!user.hasSupportedRole) {
          throw Exception('Unsupported account role. Contact support.');
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoleDispatchScreen(user: user),
          ),
        );
      } else {
        throw Exception('Invalid user data received from server.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    bool sending = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reset your password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enter the email on your account. We'll send you a link to reset your password.",
                  style: TextStyle(
                      fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'name@example.com',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showResetPasswordDialog();
              },
              child: const Text('I have a reset link'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: sending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => sending = true);
                      try {
                        final message = await _authApiService
                            .forgotPassword(emailController.text.trim());
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                        _showResetPasswordDialog();
                      } catch (e) {
                        setDialogState(() => sending = false);
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                                e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              child: sending
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send link'),
            ),
          ],
        ),
      ),
    );
  }

  String _extractResetToken(String input) {
    final text = input.trim();
    final match = RegExp(r'[?&]token=([^&\s]+)').firstMatch(text);
    return match != null ? Uri.decodeComponent(match.group(1)!) : text;
  }

  void _showResetPasswordDialog([String? initialToken]) {
    final tokenController = TextEditingController(text: initialToken ?? '');
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    bool obscure = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Set a new password'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paste the reset link from your email (valid for 15 minutes), then choose a new password.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: tokenController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reset link or code',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Reset link is required'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 5)
                        ? 'At least 5 characters'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscure,
                    decoration: const InputDecoration(
                        labelText: 'Confirm new password'),
                    validator: (v) => v != passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => submitting = true);
                      try {
                        final message = await _authApiService.resetPassword(
                          token: _extractResetToken(tokenController.text),
                          newPassword: passwordController.text,
                          confirmPassword: confirmController.text,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '$message. Please sign in with your new password.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                                e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Reset password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.warehouse_rounded,
                          color: AppColors.secondaryContainer, size: 30),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'StoreHub',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Self-Storage Management Platform',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined,
                          color: Colors.white70),
                      tooltip: 'Cài đặt IP máy chủ',
                      onPressed: _showServerConfigDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceContainerHigh),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sign in to your account',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your credentials below to continue',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.error, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                          color: AppColors.error, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isNetworkError(_errorMessage!)) ...[
                                const SizedBox(height: 10),
                                InkWell(
                                  onTap: _showServerConfigDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.error
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.wifi_tethering,
                                            size: 15, color: AppColors.error),
                                        SizedBox(width: 6),
                                        Text(
                                          'Đổi IP sang máy thật (127.0.0.1 / Wi-Fi)',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.error),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const Text('Email address',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'name@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                          helperText:
                              'Use the email address you registered with',
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(v)) {
                            return 'Enter a valid email address (e.g. name@example.com)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Password',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          GestureDetector(
                            onTap: _showForgotPasswordDialog,
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          helperText: 'Case-sensitive',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 13),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: const Text('Register now'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
