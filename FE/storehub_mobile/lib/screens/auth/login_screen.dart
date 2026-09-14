import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_api_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../customer/my_units/my_rented_units_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthApiService _authService = AuthApiService();

  final _loginUsername = TextEditingController();
  final _loginPassword = TextEditingController();

  final _regUsername = TextEditingController();
  final _regFullName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPhone = TextEditingController();
  final _regPassword = TextEditingController();

  bool _isLoading = false;
  bool _obscureLogin = true;
  bool _obscureReg = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsername.dispose();
    _loginPassword.dispose();
    _regUsername.dispose();
    _regFullName.dispose();
    _regEmail.dispose();
    _regPhone.dispose();
    _regPassword.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final u = _loginUsername.text.trim();
    final p = _loginPassword.text.trim();
    if (u.isEmpty || p.isEmpty) {
      _showMessage('Please enter username and password', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = await _authService.login(u, p);
      if (!mounted) return;

      if (auth.role == 'SYSTEM_ADMINISTRATOR' ||
          auth.role == 'ADMIN' ||
          auth.role == 'BUSINESS_OPERATIONS_MANAGER') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => AdminDashboardScreen(userRole: auth.role)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyRentedUnitsScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final u = _regUsername.text.trim();
    final name = _regFullName.text.trim();
    final em = _regEmail.text.trim();
    final ph = _regPhone.text.trim();
    final p = _regPassword.text.trim();

    if (u.isEmpty || name.isEmpty || em.isEmpty || p.isEmpty) {
      _showMessage('Please fill all required fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.register(
        username: u,
        email: em,
        password: p,
        fullName: name,
        phone: ph,
      );
      if (!mounted) return;
      _showMessage('Registration successful! Please login.');
      _tabController.animateTo(0);
      _loginUsername.text = u;
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(text),
          backgroundColor: isError ? AppColors.error : AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                const Icon(Icons.warehouse_rounded,
                    size: 64, color: AppColors.primary),
                const SizedBox(height: 8),
                const Text('StoreHub',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const Text('Self-Storage Management Platform',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          labelColor: AppColors.primary,
                          indicatorColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          tabs: const [
                            Tab(text: 'Sign In'),
                            Tab(text: 'Register')
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 380,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildLoginForm(),
                              _buildRegisterForm(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        TextField(
          controller: _loginUsername,
          decoration: const InputDecoration(
              labelText: 'Username or Email',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _loginPassword,
          obscureText: _obscureLogin,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
                icon: Icon(
                    _obscureLogin ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscureLogin = !_obscureLogin)),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Sign In',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
              controller: _regUsername,
              decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: 10),
          TextField(
              controller: _regFullName,
              decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: 10),
          TextField(
              controller: _regEmail,
              decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: 10),
          TextField(
              controller: _regPhone,
              decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: 10),
          TextField(
            controller: _regPassword,
            obscureText: _obscureReg,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                  icon: Icon(
                      _obscureReg ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureReg = !_obscureReg)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Create Account'),
            ),
          ),
        ],
      ),
    );
  }
}
