import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/admin_api_service.dart';
import '../../models/paged_result.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../../core/utils/vi_labels.dart';
import '../../widgets/state_views.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AdminApiService _adminService = AdminApiService();
  late Future<PagedResult<Map<String, dynamic>>> _usersFuture;
  final List<Map<String, dynamic>> _additional = [];
  int _nextPage = 1;
  bool _lastPage = false;
  bool _loadingMore = false;
  Timer? _searchTimer;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() {
    setState(() {
      _additional.clear();
      _nextPage = 1;
      _lastPage = false;
      _usersFuture = _adminService.getUsersPage(search: _query,
          isActive: _statusFilter == 'ALL' ? null : _statusFilter == 'ACTIVE');
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _lastPage) return;
    final currentLoad = _usersFuture;
    setState(() => _loadingMore = true);
    try {
      final page = await _adminService.getUsersPage(page: _nextPage, search: _query,
          isActive: _statusFilter == 'ALL' ? null : _statusFilter == 'ACTIVE');
      if (!mounted || !identical(currentLoad, _usersFuture)) return;
      setState(() {
        _additional.addAll(page.content);
        _nextPage++;
        _lastPage = page.last;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _showAssignRoleSheet(
      String userId, String username, String currentPhone) async {
    List<dynamic> roles;
    try {
      roles = await _adminService.getRoles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Không tải được danh sách vai trò: ${e.toString().replaceAll('Exception: ', '')}')),
      );
      return;
    }

    if (roles.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có vai trò nào.')),
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gán vai trò cho $username',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ...roles.map((r) {
              final id = r['id']?.toString() ?? '';
              final name = r['name']?.toString() ?? id;
              final description = r['description']?.toString();
              return ListTile(
                leading: const Icon(Icons.badge_outlined,
                    color: AppColors.primaryContainer),
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: description != null && description.isNotEmpty
                    ? Text(description)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _adminService.updateUserRole(
                        userId, id, currentPhone);
                    _loadUsers();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$username hiện là $name'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(Map user) async {
    final userId = user['id']?.toString() ?? '';
    final wasActive = user['isActive'] == true;
    try {
      await _adminService.toggleUserActive(userId);
      _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(wasActive ? 'Đã vô hiệu hóa người dùng' : 'Đã kích hoạt người dùng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openUserDetail(Map<String, dynamic> user) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _UserDetailSheet(service: _adminService, user: user),
    );
    if (!mounted || action == null) return;
    final userId = user['id']?.toString() ?? '';
    final username = user['username']?.toString() ?? 'Unknown';
    final fullName = user['fullName']?.toString() ?? username;
    final phone = user['phone']?.toString() ?? '';
    switch (action) {
      case 'role':
        await _showAssignRoleSheet(userId, fullName, phone);
        break;
      case 'toggle':
        await _toggleActive(user);
        break;
      case 'delete':
        await _confirmDelete(user);
        break;
    }
  }

  Future<void> _showCreateUserSheet() async {
    List<dynamic> roles;
    try {
      roles = await _adminService.getRoles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error),
      );
      return;
    }
    if (!mounted) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateUserSheet(
        service: _adminService,
        roles: roles
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      ),
    );
    if (created == true) {
      _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã tạo người dùng'),
            backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    final name = user['fullName']?.toString() ??
        user['username']?.toString() ??
        'người dùng này';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: Text(
            'Xóa vĩnh viễn tài khoản "$name"? Nếu tài khoản đã có đơn thuê, '
            'yêu cầu hỗ trợ hoặc nhật ký, hệ thống sẽ không cho xóa - '
            'khi đó hãy dùng nút vô hiệu hóa.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _adminService.deleteUser(userId);
      _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã xóa tài khoản'),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Người dùng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateUserSheet,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm người dùng'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                _query = v.trim();
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 350), _loadUsers);
              },
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên, tên đăng nhập hoặc email',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _filterChip('Tất cả', 'ALL'),
                const SizedBox(width: 8),
                _filterChip('Đang hoạt động', 'ACTIVE'),
                const SizedBox(width: 8),
                _filterChip('Ngừng hoạt động', 'INACTIVE'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadUsers(),
              child: FutureBuilder<PagedResult<Map<String, dynamic>>>(
                future: _usersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppLoadingState(message: 'Đang tải người dùng...');
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        AppErrorState(
                          message: snapshot.error
                              .toString()
                              .replaceAll('Exception: ', ''),
                          onRetry: _loadUsers,
                        ),
                      ],
                    );
                  }

                  final users = [...?snapshot.data?.content, ..._additional];
                  final hasMore = snapshot.data != null && !snapshot.data!.last && !_lastPage;

                  if (users.isEmpty) {
                    return ListView(
                      children: const [
                        AppEmptyState(
                          icon: Icons.people_outline,
                          title: 'Không tìm thấy người dùng',
                          message: 'Không có người dùng nào phù hợp bộ lọc.',
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: users.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == users.length) {
                        return Center(child: TextButton(
                          onPressed: _loadingMore ? null : _loadMore,
                          child: Text(_loadingMore ? 'Đang tải...' : 'Xem thêm người dùng'),
                        ));
                      }
                      final user = users[index];
                      final userId = user['id']?.toString() ?? '';
                      final username =
                          user['username']?.toString() ?? 'Unknown';
                      final fullName = user['fullName']?.toString() ?? username;
                      final email = user['email']?.toString() ?? '';
                      final phone = user['phone']?.toString() ?? '';
                      final isActive = user['isActive'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: isActive
                                ? AppColors.primaryContainer
                                : AppColors.outline,
                            child: Text(
                              _initials(fullName),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          onTap: () => _openUserDetail(user),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${ViLabels.role(user['roleName']?.toString())}\n'
                              '@$username • $email${phone.isNotEmpty ? '\n$phone' : ''}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                onChanged: (_) => _toggleActive(user),
                                activeThumbColor: AppColors.success,
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.badge_outlined, size: 20),
                                tooltip: 'Gán vai trò',
                                onPressed: () => _showAssignRoleSheet(
                                    userId, fullName, phone),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        _statusFilter = value;
        _loadUsers();
      },
    );
  }
}

String _fmtDate(dynamic value) {
  final dt = value == null ? null : DateTime.tryParse(value.toString());
  return dt == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
}

class _UserDetailSheet extends StatefulWidget {
  final AdminApiService service;
  final Map<String, dynamic> user;
  const _UserDetailSheet({required this.service, required this.user});

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  late final Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.getUserDetail(widget.user['id'].toString());
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final data = snapshot.data ?? widget.user;
            final isActive = data['isActive'] == true;
            final roleName = data['roleName']?.toString();
            final isAdmin = (roleName ?? '').toUpperCase() == 'ADMIN';
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Chi tiết người dùng',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    if (loading)
                      const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 8),
                _row('Họ tên', data['fullName']?.toString() ?? ''),
                _row('Tên đăng nhập', data['username']?.toString() ?? ''),
                _row('Email', data['email']?.toString() ?? ''),
                _row('Số điện thoại', data['phone']?.toString() ?? ''),
                _row('Vai trò', ViLabels.role(roleName)),
                _row('Trạng thái', isActive ? 'Đang hoạt động' : 'Ngừng hoạt động'),
                _row('Cấp vai trò lúc', _fmtDate(data['assignedAt'])),
                _row('Ngày tạo', _fmtDate(data['createdAt'])),
                if (snapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Không tải được thông tin mới nhất, đang hiển thị dữ liệu trong danh sách.',
                        style: TextStyle(fontSize: 11, color: AppColors.error)),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, 'role'),
                        icon: const Icon(Icons.badge_outlined, size: 18),
                        label: const Text('Gán vai trò'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context, 'toggle'),
                        icon: Icon(
                            isActive
                                ? Icons.block_outlined
                                : Icons.check_circle_outline,
                            size: 18),
                        label: Text(isActive ? 'Vô hiệu hóa' : 'Kích hoạt'),
                      ),
                    ),
                  ],
                ),
                if (!isAdmin) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context, 'delete'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.error),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Xóa tài khoản'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CreateUserSheet extends StatefulWidget {
  final AdminApiService service;
  final List<Map<String, dynamic>> roles;
  const _CreateUserSheet({required this.service, required this.roles});

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _roleId;
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final r in widget.roles) {
      if ((r['name']?.toString() ?? '').toUpperCase() == 'CUSTOMER') {
        _roleId = r['id']?.toString();
      }
    }
    _roleId ??= widget.roles.isNotEmpty ? widget.roles.first['id']?.toString() : null;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.createUser(
        username: _username.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim(),
        roleId: _roleId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thêm người dùng',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Họ tên'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Vui lòng nhập họ tên';
                    if (t.length > 30) return 'Họ tên tối đa 30 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.length < 3 || t.length > 30) {
                      return 'Tên đăng nhập từ 3 đến 30 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Vui lòng nhập email';
                    if (!RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$')
                        .hasMatch(t)) {
                      return 'Email không đúng định dạng';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (!RegExp(r'^(0|\+84)(3|5|7|8|9)[0-9]{8}$').hasMatch(t)) {
                      return 'Số điện thoại Việt Nam không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v ?? '').length < 6
                      ? 'Mật khẩu tối thiểu 6 ký tự'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _roleId,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: widget.roles
                      .map((r) => DropdownMenuItem<String>(
                            value: r['id']?.toString(),
                            child: Text(ViLabels.role(r['name']?.toString())),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _roleId = v),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.error)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Tạo người dùng'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
