import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthApiService _authService = AuthApiService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _fullNameController.text.trim(),
        _phoneController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tạo tài khoản thành công! Vui lòng đăng nhập.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Tạo tài khoản'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceContainerHigh),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tham gia StoreHub',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Điền thông tin để tạo tài khoản khách hàng',
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
                      child: Row(
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
                    ),
                  const _FieldLabel('Họ và tên'),
                  TextFormField(
                    controller: _fullNameController,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'VD: Nguyễn Văn A',
                      prefixIcon: Icon(Icons.person_outline),
                      helperText: 'Tối đa 30 ký tự',
                      counterText: '',
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Vui lòng nhập họ tên';
                      if (v.length > 30) {
                        return 'Họ tên tối đa 30 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Tên đăng nhập'),
                  TextFormField(
                    controller: _usernameController,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      hintText: 'VD: nguyenvana',
                      prefixIcon: Icon(Icons.account_circle_outlined),
                      helperText:
                          'Từ 3 đến 30 ký tự, hiển thị trên hồ sơ',
                      counterText: '',
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Vui lòng nhập tên đăng nhập';
                      if (v.length < 3 || v.length > 30) {
                        return 'Tên đăng nhập phải từ 3 đến 30 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Địa chỉ email'),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'ten@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      helperText: "Bạn sẽ dùng email này để đăng nhập",
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Vui lòng nhập email';
                      if (!RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$')
                          .hasMatch(v)) {
                        return 'Nhập email hợp lệ';
                      }
                      if (v.length > 255) {
                        return 'Email tối đa 255 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Số điện thoại'),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 0912345678',
                      prefixIcon: Icon(Icons.phone_outlined),
                      helperText:
                          'Số di động Việt Nam, bắt đầu bằng 0 hoặc +84',
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Vui lòng nhập số điện thoại';
                      if (!RegExp(r'^(0|\+84)(3|5|7|8|9)[0-9]{8}$')
                          .hasMatch(v)) {
                        return 'Nhập số điện thoại Việt Nam hợp lệ (VD: 0912345678)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Mật khẩu'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Tạo mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      helperText: 'Tối thiểu 5 ký tự',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (value.length < 5) {
                        return 'Mật khẩu tối thiểu 5 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Tạo tài khoản'),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Đã có tài khoản? Đăng nhập'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
