import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/vi_labels.dart';
import '../../services/admin_api_service.dart';
import '../../widgets/state_views.dart';

class RolePermissionScreen extends StatefulWidget {
  final bool readOnly;
  const RolePermissionScreen({super.key, this.readOnly = false});

  @override
  State<RolePermissionScreen> createState() => _RolePermissionScreenState();
}

class _RolePermissionScreenState extends State<RolePermissionScreen> {
  final AdminApiService _adminApiService = AdminApiService();

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

  @override
  void initState() {
    super.initState();
    _loadRolesAndPermissions();
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
          .toList();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  bool get _isDirty =>
      !setEquals(_selectedPermissionIds, _initialPermissionIds);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật quyền'),
          backgroundColor: AppColors.success,
        ),
      );
      await _selectRole(_selectedRoleId!);
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

  Map<String, dynamic>? get _selectedRole {
    for (final r in _roles) {
      if (r['id'].toString() == _selectedRoleId) return r;
    }
    return null;
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  /// Hộp thoại sửa mô tả dùng chung cho vai trò và quyền.
  Future<String?> _askDescription(
      {required String title,
      required String subtitle,
      required String initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLength: 255,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Lưu')),
        ],
      ),
    );
  }

  Future<void> _editRoleDescription() async {
    final id = _selectedRoleId;
    if (id == null) return;
    try {
      final detail = await _adminApiService.getRoleDetail(id);
      if (!mounted) return;
      final text = await _askDescription(
        title: 'Vai trò: ${ViLabels.role(detail['name']?.toString())}',
        subtitle: 'Tên vai trò là cố định theo hệ thống, chỉ sửa được mô tả.',
        initial: detail['description']?.toString() ?? '',
      );
      if (text == null) return;
      await _adminApiService.updateRoleDescription(detail, text);
      final roles = (await _adminApiService.getRoles())
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() => _roles = roles);
      _toast('Đã cập nhật mô tả vai trò');
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Future<void> _showPermissionDetail(Map<String, dynamic> permission) async {
    try {
      final detail =
          await _adminApiService.getPermissionDetail(permission['id'].toString());
      if (!mounted) return;
      final text = await _askDescription(
        title: detail['name']?.toString() ?? 'Quyền',
        subtitle: 'Nhóm: ${detail['permissionGroup'] ?? 'Chung'}'
            '${widget.readOnly ? '' : ' - chỉ sửa được mô tả (tên quyền gắn với mã nguồn).'}',
        initial: detail['description']?.toString() ?? '',
      );
      if (text == null || widget.readOnly) return;
      await _adminApiService.updatePermissionDescription(detail, text);
      final permissions = (await _adminApiService.getPermissions())
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() => _permissions = permissions);
      _toast('Đã cập nhật mô tả quyền');
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  Map<String, List<Map<String, dynamic>>> get _groupedPermissions {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final p in _permissions) {
      final group = (p['permissionGroup']?.toString().isNotEmpty ?? false)
          ? p['permissionGroup'].toString()
          : 'Chung';
      map.putIfAbsent(group, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Vai trò & quyền hạn'),
      ),
      body: _isLoadingRoles
          ? const AppLoadingState(message: 'Đang tải vai trò & quyền hạn...')
          : _error != null
              ? AppErrorState(
                  message: _error!,
                  onRetry: _loadRolesAndPermissions,
                )
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        'Chọn vai trò để xem quyền. Admin tích/bỏ rồi bấm Lưu thay đổi. '
                        'Vai trò quyết định màn hình; quyền là lớp kiểm tra bổ sung '
                        'cho các API quản trị, giá, chính sách và báo cáo.',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _roles.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final role = _roles[index];
                            final roleId = role['id'].toString();
                            final selected = roleId == _selectedRoleId;
                            return ChoiceChip(
                              label: Text(ViLabels.role(role['name']?.toString())),
                              selected: selected,
                              onSelected: (_) {
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              (_selectedRole?['description']?.toString().isNotEmpty ?? false)
                                  ? _selectedRole!['description'].toString()
                                  : 'Chưa có mô tả cho vai trò này.',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ),
                          if (!widget.readOnly && _selectedRole != null)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Sửa mô tả vai trò',
                              onPressed: _editRoleDescription,
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _isLoadingMatrix
                          ? const Center(child: CircularProgressIndicator())
                          : _permissions.isEmpty
                              ? const Center(
                                  child: Text('Chưa có quyền nào được định nghĩa.'))
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 12, 16, 100),
                                  children:
                                      _groupedPermissions.entries.map((entry) {
                                    return _buildGroupSection(
                                        entry.key, entry.value);
                                  }).toList(),
                                ),
                    ),
                  ],
                ),
      bottomNavigationBar: (!widget.readOnly && _isDirty)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Lưu thay đổi'),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _confirmDiscardThenSwitch(String newRoleId) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ các thay đổi chưa lưu?'),
        content: const Text(
            'Chuyển vai trò sẽ bỏ các thay đổi quyền chưa lưu.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tiếp tục chỉnh sửa')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bỏ thay đổi')),
        ],
      ),
    );
    if (discard == true) {
      _selectRole(newRoleId);
    }
  }

  Widget _buildGroupSection(
      String group, List<Map<String, dynamic>> permissions) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Text(
                group,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...permissions.map((p) {
              final id = p['id'].toString();
              final checked = _selectedPermissionIds.contains(id);
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(p['name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13)),
                subtitle: (p['description']?.toString().isNotEmpty ?? false)
                    ? Text(p['description'].toString(),
                        style: const TextStyle(fontSize: 11))
                    : null,
                value: checked,
                secondary: IconButton(
                  icon: const Icon(Icons.info_outline, size: 18),
                  tooltip: widget.readOnly ? 'Xem chi tiết quyền' : 'Chi tiết / sửa mô tả',
                  onPressed: () => _showPermissionDetail(p),
                ),
                onChanged: widget.readOnly
                    ? null
                    : (value) {
                        setState(() {
                          if (value == true) {
                            _selectedPermissionIds.add(id);
                          } else {
                            _selectedPermissionIds.remove(id);
                          }
                        });
                      },
              );
            }),
          ],
        ),
      ),
    );
  }
}
