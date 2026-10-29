import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/admin_api_service.dart';
import '../../widgets/state_views.dart';
import 'role_permission_meta.dart';

enum PermissionFilter { all, active, inactive }

class RolePermissionScreen extends StatefulWidget {
  final bool readOnly;
  const RolePermissionScreen({super.key, this.readOnly = false});

  @override
  State<RolePermissionScreen> createState() => _RolePermissionScreenState();
}

class _RolePermissionScreenState extends State<RolePermissionScreen> {
  final AdminApiService _adminApiService = AdminApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoadingRoles = true;
  bool _isLoadingMatrix = false;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permissions = [];
  String? _selectedRoleId;

  Map<String, String> _assignedIds = {};
  Set<String> _selectedPermissionIds = {};
  Set<String> _initialPermissionIds = {};

  String _searchQuery = '';
  PermissionFilter _filter = PermissionFilter.all;

  @override
  void initState() {
    super.initState();
    _loadRolesAndPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRolesAndPermissions() async {
    setState(() {
      _isLoadingRoles = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _adminApiService.getRoles(),
        _adminApiService.getPermissions(),
      ]);
      final roles = results[0]
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((r) {
            final name = (r['name']?.toString() ?? '').toUpperCase();
            return name != 'ADMIN' && name != 'CUSTOMER';
          })
          .toList();

      const preferredOrder = ['FACILITY_MANAGER', 'STAFF', 'BUSINESS_MANAGER'];
      roles.sort((a, b) {
        final aName = (a['name']?.toString() ?? '').toUpperCase();
        final bName = (b['name']?.toString() ?? '').toUpperCase();
        final aIdx = preferredOrder.indexOf(aName);
        final bIdx = preferredOrder.indexOf(bName);
        if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
        if (aIdx != -1) return -1;
        if (bIdx != -1) return 1;
        return aName.compareTo(bName);
      });
      final permissions = results[1]
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _roles = roles;
        _permissions = permissions;
        _isLoadingRoles = false;
      });
      if (roles.isNotEmpty) {
        _selectRole(roles.first['id'].toString());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoadingRoles = false;
      });
    }
  }

  Future<void> _selectRole(String roleId) async {
    setState(() {
      _selectedRoleId = roleId;
      _isLoadingMatrix = true;
    });
    try {
      final assigned = await _adminApiService.getRolePermissionsByRole(roleId);
      final assignedIds = <String, String>{};
      final selected = <String>{};
      for (final item in assigned) {
        if (item is! Map) continue;
        final permissionId = item['permissionId']?.toString();
        final id = item['id']?.toString();
        final isActive = item['isActive'] == true;
        if (permissionId == null || id == null) continue;
        if (isActive) {
          assignedIds[permissionId] = id;
          selected.add(permissionId);
        }
      }
      if (!mounted) return;
      setState(() {
        _assignedIds = assignedIds;
        _selectedPermissionIds = selected;
        _initialPermissionIds = Set.from(selected);
        _isLoadingMatrix = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMatrix = false;
      });
      _toast(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  bool get _isDirty =>
      !setEquals(_selectedPermissionIds, _initialPermissionIds);

  Map<String, dynamic>? get _selectedRole {
    for (final r in _roles) {
      if (r['id'].toString() == _selectedRoleId) return r;
    }
    return null;
  }

  RoleMeta get _currentRoleMeta {
    final roleName = _selectedRole?['name']?.toString();
    return RolePermissionHelper.getRoleMeta(roleName);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedRoleId == null) return;
    final toAdd = _selectedPermissionIds.difference(_initialPermissionIds);
    final toRemove = _initialPermissionIds.difference(_selectedPermissionIds);

    setState(() => _isSaving = true);
    try {
      if (toAdd.isNotEmpty) {
        await _adminApiService.bulkAssignPermissions(
            _selectedRoleId!, toAdd.toList());
      }
      for (final permissionId in toRemove) {
        final rolePermissionId = _assignedIds[permissionId];
        if (rolePermissionId != null) {
          await _adminApiService.revokeRolePermission(rolePermissionId);
        }
      }
      if (!mounted) return;
      _toast('Đã lưu phân quyền cho ${_currentRoleMeta.viName} thành công!');
      await _selectRole(_selectedRoleId!);
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetToDefaultPreset() {
    final meta = _currentRoleMeta;
    final defaultCodes = meta.defaultPermissions.toSet();

    if (defaultCodes.isEmpty) {
      _toast('Không có mẫu quyền mặc định cho vai trò này', error: true);
      return;
    }

    final newSelected = <String>{};
    for (final p in _permissions) {
      final code = p['name']?.toString() ?? '';
      if (defaultCodes.contains(code)) {
        newSelected.add(p['id'].toString());
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.restore_rounded, color: meta.color, size: 24),
            const SizedBox(width: 10),
            const Text('Khôi phục quyền chuẩn', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Hệ thống sẽ chọn ${newSelected.length} quyền tiêu chuẩn theo đúng nhiệm vụ của "${meta.viName}".\n\n'
          'Sau khi bấm Áp dụng, bạn nhớ bấm nút "Lưu thay đổi" ở góc dưới để hệ thống cập nhật.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: meta.color),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedPermissionIds = newSelected;
              });
              _toast('Đã chọn mẫu quyền chuẩn cho ${meta.viName}. Nhớ bấm Lưu!');
            },
            child: const Text('Áp dụng mẫu'),
          ),
        ],
      ),
    );
  }

  void _toggleGroupPermissions(List<Map<String, dynamic>> groupPermissions, bool enable) {
    setState(() {
      for (final p in groupPermissions) {
        final id = p['id'].toString();
        if (enable) {
          _selectedPermissionIds.add(id);
        } else {
          _selectedPermissionIds.remove(id);
        }
      }
    });
  }

  Future<void> _confirmDiscardThenSwitch(String newRoleId) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bỏ các thay đổi chưa lưu?'),
        content: const Text(
          'Bạn đang có các quyền vừa thay đổi chưa bấm Lưu. Nếu chuyển vai trò, các thay đổi này sẽ bị hủy bỏ.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục chỉnh sửa'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    if (discard == true) {
      _selectRole(newRoleId);
    }
  }

  Future<void> _editRoleDescription() async {
    final id = _selectedRoleId;
    if (id == null) return;
    try {
      final detail = await _adminApiService.getRoleDetail(id);
      if (!mounted) return;
      final controller = TextEditingController(text: detail['description']?.toString() ?? '');
      final text = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Sửa mô tả: ${_currentRoleMeta.viName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mô tả giúp các thành viên quản trị hiểu rõ nhiệm vụ của vai trò này.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 255,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả vai trò',
                  hintText: 'Nhập tóm tắt nhiệm vụ...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Lưu'),
            ),
          ],
        ),
      );
      if (text == null) return;
      await _adminApiService.updateRoleDescription(detail, text);
      final roles = (await _adminApiService.getRoles())
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((r) {
            final name = (r['name']?.toString() ?? '').toUpperCase();
            return name != 'ADMIN' && name != 'CUSTOMER';
          })
          .toList();

      const preferredOrder = ['FACILITY_MANAGER', 'STAFF', 'BUSINESS_MANAGER'];
      roles.sort((a, b) {
        final aName = (a['name']?.toString() ?? '').toUpperCase();
        final bName = (b['name']?.toString() ?? '').toUpperCase();
        final aIdx = preferredOrder.indexOf(aName);
        final bIdx = preferredOrder.indexOf(bName);
        if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
        if (aIdx != -1) return -1;
        if (bIdx != -1) return 1;
        return aName.compareTo(bName);
      });
      if (!mounted) return;
      setState(() => _roles = roles);
      _toast('Đã cập nhật mô tả vai trò');
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  void _showHelpGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.secondary, size: 24),
            SizedBox(width: 10),
            Text('Hướng dẫn phân quyền', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Vai trò trong hệ thống:\n'
                '   • Quản lý cơ sở (FACILITY_MANAGER): Quản lý chi nhánh kho, duyệt hoàn cọc, gán ngăn kho & nhân viên.\n'
                '   • Nhân viên cơ sở (STAFF): Bàn giao Check-in, nghiệm thu Check-out, quét mã QR cổng, xử lý ticket tại chỗ.\n'
                '   • Quản lý vận hành (BUSINESS_MANAGER): Giám sát doanh thu, điều chỉnh bảng giá loại kho và chính sách.\n'
                '   • Quản trị viên (ADMIN) & Khách hàng (CUSTOMER): Có cơ chế quyền hạn cố định theo thiết kế hệ thống, không cần cấu hình phân quyền.\n\n'
                '2. Quyền hạn (Permission) là chốt chặn bảo mật:\n'
                '   • Là quyền thực hiện từng nghiệp vụ thực tế (duyệt hoàn cọc, gán ngăn, check-in...).\n'
                '   • Ví dụ: Nếu Quản lý cơ sở bị tắt quyền "Duyệt chuyển khoản hoàn cọc" (REFUND_APPROVE), họ sẽ bị chặn khi bấm xác nhận hoàn tiền cọc cho khách.\n\n'
                '3. Cách sử dụng:\n'
                '   • Chọn vai trò ở thanh trên cùng.\n'
                '   • Bật hoặc tắt các quyền nghiệp vụ cần thiết.\n'
                '   • Bấm nút "Lưu thay đổi" ở thanh dưới cùng để áp dụng.',
                style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDetailModal(Map<String, dynamic> permission) {
    final code = permission['name']?.toString() ?? '';
    final rawDesc = permission['description']?.toString();
    final rawGroup = permission['permissionGroup']?.toString();
    final meta = RolePermissionHelper.getPermissionMeta(code, rawGroup, rawDesc);
    final id = permission['id'].toString();
    final isChecked = _selectedPermissionIds.contains(id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (meta.isDangerous ? AppColors.error : AppColors.secondary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    meta.groupIcon,
                    color: meta.isDangerous ? AppColors.error : AppColors.secondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.viTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _detailRow(
              icon: Icons.lightbulb_outline_rounded,
              color: AppColors.secondary,
              label: 'Tác dụng của quyền:',
              content: meta.explanation,
            ),
            const SizedBox(height: 12),
            _detailRow(
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
              label: 'Khi được bật (Cấp quyền):',
              content: meta.effectWhenOn,
            ),
            const SizedBox(height: 12),
            _detailRow(
              icon: Icons.block_rounded,
              color: AppColors.error,
              label: 'Khi bị tắt (Chặn quyền):',
              content: meta.effectWhenOff,
            ),
            if (meta.isDangerous) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lưu ý: Quyền nhạy cảm có thể ảnh hưởng đến dữ liệu hoặc tài chính.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (!widget.readOnly)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isChecked ? AppColors.error : AppColors.secondary,
                  ),
                  icon: Icon(isChecked ? Icons.remove_circle_outline : Icons.check_circle_outline, size: 18),
                  label: Text(isChecked ? 'Bỏ quyền này' : 'Cấp quyền này'),
                  onPressed: () {
                    setState(() {
                      if (isChecked) {
                        _selectedPermissionIds.remove(id);
                      } else {
                        _selectedPermissionIds.add(id);
                      }
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required Color color,
    required String label,
    required String content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _roleScopedPermissions {
    final applicableList = _currentRoleMeta.applicablePermissions;
    if (applicableList.isEmpty) return _permissions;
    final applicableSet = applicableList.toSet();
    return _permissions.where((p) {
      final code = p['name']?.toString() ?? '';
      return applicableSet.contains(code);
    }).toList();
  }

  int get _scopedActiveCount {
    int count = 0;
    for (final p in _roleScopedPermissions) {
      final id = p['id'].toString();
      if (_selectedPermissionIds.contains(id)) {
        count++;
      }
    }
    return count;
  }

  Map<String, List<Map<String, dynamic>>> get _filteredGroupedPermissions {
    final query = _searchQuery.trim().toLowerCase();
    final map = <String, List<Map<String, dynamic>>>{};

    for (final p in _roleScopedPermissions) {
      final id = p['id'].toString();
      final code = p['name']?.toString() ?? '';
      final rawDesc = p['description']?.toString() ?? '';
      final rawGroup = p['permissionGroup']?.toString();
      final meta = RolePermissionHelper.getPermissionMeta(code, rawGroup, rawDesc);

      final isChecked = _selectedPermissionIds.contains(id);

      if (_filter == PermissionFilter.active && !isChecked) continue;
      if (_filter == PermissionFilter.inactive && isChecked) continue;

      if (query.isNotEmpty) {
        final matchCode = code.toLowerCase().contains(query);
        final matchTitle = meta.viTitle.toLowerCase().contains(query);
        final matchDesc = meta.explanation.toLowerCase().contains(query);
        final matchGroup = meta.groupViTitle.toLowerCase().contains(query);
        if (!matchCode && !matchTitle && !matchDesc && !matchGroup) continue;
      }

      final group = meta.groupViTitle;
      map.putIfAbsent(group, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final currentMeta = _currentRoleMeta;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Bỏ các thay đổi chưa lưu?'),
            content: const Text(
              'Bạn đang có thay đổi phân quyền chưa bấm Lưu. Bạn có chắc muốn thoát?',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ở lại')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Thoát'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Vai trò & quyền hạn'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: 'Hướng dẫn',
              onPressed: _showHelpGuide,
            ),
            if (!widget.readOnly && _isDirty)
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _selectedPermissionIds = Set.from(_initialPermissionIds);
                        });
                        _toast('Đã hoàn tác thay đổi');
                      },
                child: const Text('Hoàn tác', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              ),
            if (!widget.readOnly)
              IconButton(
                icon: const Icon(Icons.restore_rounded),
                tooltip: 'Khôi phục quyền chuẩn',
                onPressed: _resetToDefaultPreset,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: _isLoadingRoles
            ? const AppLoadingState(message: 'Đang tải danh sách vai trò & quyền hạn...')
            : _error != null
                ? AppErrorState(
                    message: _error!,
                    onRetry: _loadRolesAndPermissions,
                  )
                : Column(
                    children: [
                      // 1. Horizontal Role Chips Selector
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _roles.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final role = _roles[index];
                              final roleId = role['id'].toString();
                              final isSelected = roleId == _selectedRoleId;
                              final meta = RolePermissionHelper.getRoleMeta(role['name']?.toString());

                              return ChoiceChip(
                                avatar: Icon(
                                  meta.icon,
                                  size: 16,
                                  color: isSelected ? Colors.white : meta.color,
                                ),
                                label: Text(meta.viName),
                                selected: isSelected,
                                selectedColor: meta.color,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                                onSelected: (_) {
                                  if (roleId == _selectedRoleId) return;
                                  if (_isDirty) {
                                    _confirmDiscardThenSwitch(roleId);
                                  } else {
                                    _selectRole(roleId);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1),

                      // 2. Active Role Hero Banner Card
                      Card(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: currentMeta.color.withValues(alpha: 0.3)),
                        ),
                        color: currentMeta.color.withValues(alpha: 0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: currentMeta.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(currentMeta.icon, color: currentMeta.color, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentMeta.viName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: currentMeta.color,
                                          ),
                                        ),
                                        Text(
                                          'Mã: ${currentMeta.roleKey} • ${currentMeta.badge}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!widget.readOnly) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      tooltip: 'Sửa mô tả vai trò',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: _editRoleDescription,
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: _resetToDefaultPreset,
                                      icon: const Icon(Icons.restore, size: 14),
                                      label: const Text('Mặc định', style: TextStyle(fontSize: 11)),
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentMeta.summary,
                                style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.screen_share_outlined, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Màn hình chính: ${currentMeta.mainScreen}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Search and Status Filter Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Tìm quyền (VD: cọc, PIN, hợp đồng, tài khoản...)',
                            hintStyle: const TextStyle(fontSize: 12, color: AppColors.outline),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.outlineVariant),
                            ),
                          ),
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),

                      if (_currentRoleMeta.applicablePermissions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: currentMeta.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: currentMeta.color.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 16,
                                  color: currentMeta.color,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Danh sách quyền nghiệp vụ áp dụng cho ${currentMeta.viName}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: currentMeta.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Row(
                          children: [
                            Text(
                              'Đã cấp: $_scopedActiveCount/${_roleScopedPermissions.length}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            _filterChip('Tất cả', PermissionFilter.all),
                            const SizedBox(width: 4),
                            _filterChip('Đang bật', PermissionFilter.active),
                            const SizedBox(width: 4),
                            _filterChip('Đã tắt', PermissionFilter.inactive),
                          ],
                        ),
                      ),

                      // 4. Permission Groups List
                      Expanded(
                        child: _isLoadingMatrix
                            ? const Center(child: CircularProgressIndicator())
                            : _filteredGroupedPermissions.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.search_off_rounded, size: 44, color: AppColors.outline),
                                        const SizedBox(height: 8),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'Không tìm thấy quyền phù hợp với "$_searchQuery"'
                                              : 'Không có quyền nào trong mục này.',
                                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                    children: _filteredGroupedPermissions.entries.map((entry) {
                                      return _buildBusinessGroupCard(entry.key, entry.value);
                                    }).toList(),
                                  ),
                      ),

                      // 5. Always Visible Bottom Save Bar (pinned inside Column)
                      if (!widget.readOnly) _buildPersistentBottomBar(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPersistentBottomBar() {
    final isDirty = _isDirty;
    final changeCount = _selectedPermissionIds.difference(_initialPermissionIds).length +
        _initialPermissionIds.difference(_selectedPermissionIds).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDirty ? 0.08 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDirty ? AppColors.secondary : AppColors.outlineVariant,
            width: isDirty ? 1.5 : 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDirty ? AppColors.secondary : AppColors.surfaceContainerLow,
            foregroundColor: isDirty ? Colors.white : AppColors.textSecondary,
            elevation: isDirty ? 2 : 0,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (!isDirty || _isSaving) ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  isDirty
                      ? 'Lưu thay đổi ($changeCount quyền thay đổi)'
                      : 'Lưu thay đổi (Chưa có thay đổi)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, PermissionFilter filter) {
    final isSelected = _filter == filter;
    return InkWell(
      onTap: () => setState(() => _filter = filter),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessGroupCard(String groupTitle, List<Map<String, dynamic>> perms) {
    final activeCount = perms.where((p) => _selectedPermissionIds.contains(p['id'].toString())).length;
    final allChecked = activeCount == perms.length;

    final firstCode = perms.first['name']?.toString() ?? '';
    final firstMeta = RolePermissionHelper.getPermissionMeta(firstCode);
    final groupIcon = firstMeta.groupIcon;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(
                children: [
                  Icon(groupIcon, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      groupTitle,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeCount > 0
                          ? AppColors.secondary.withValues(alpha: 0.12)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeCount/${perms.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: activeCount > 0 ? AppColors.secondary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (!widget.readOnly) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _toggleGroupPermissions(perms, !allChecked),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          allChecked ? 'Bỏ chọn' : 'Chọn hết',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: allChecked ? AppColors.error : AppColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Permission Items using robust CheckboxListTile
            ...perms.map((p) {
              final id = p['id'].toString();
              final code = p['name']?.toString() ?? '';
              final rawDesc = p['description']?.toString();
              final meta = RolePermissionHelper.getPermissionMeta(code, null, rawDesc);
              final isChecked = _selectedPermissionIds.contains(id);

              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
                value: isChecked,
                activeColor: AppColors.secondary,
                onChanged: widget.readOnly
                    ? null
                    : (val) {
                        setState(() {
                          if (val == true) {
                            _selectedPermissionIds.add(id);
                          } else {
                            _selectedPermissionIds.remove(id);
                          }
                        });
                      },
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        meta.viTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isChecked ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (meta.isDangerous)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Nhạy cảm',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: AppColors.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.explanation,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.25,
                        color: isChecked ? AppColors.textSecondary : AppColors.outline,
                      ),
                    ),
                  ],
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.secondary),
                  tooltip: 'Xem tác dụng khi Bật/Tắt',
                  onPressed: () => _showPermissionDetailModal(p),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
