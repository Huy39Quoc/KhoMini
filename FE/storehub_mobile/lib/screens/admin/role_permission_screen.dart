import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/admin_api_service.dart';

/// RBAC Matrix: pick a role, see every permission grouped by category, and
/// (for Admins) toggle which ones that role has. All data - roles,
/// permissions, and the current assignment - is real, fetched from
/// RoleController / PermissionController / RolePermissionController.
/// [readOnly] is used for roles that can view (Business Manager, Facility
/// Manager) but aren't allowed to edit (BE only allows ADMIN to write).
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

  // permissionId -> rolePermission record id (existing assignment), for permissions currently active on the role
  Map<String, String> _assignedIds = {};
  // Local editable selection (checked permission ids)
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
      final roles = results[0].whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final permissions = results[1].whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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

  bool get _isDirty => !setEquals(_selectedPermissionIds, _initialPermissionIds);

  Future<void> _save() async {
    if (_selectedRoleId == null) return;
    final toAdd = _selectedPermissionIds.difference(_initialPermissionIds);
    final toRemove = _initialPermissionIds.difference(_selectedPermissionIds);

    setState(() => _isSaving = true);
    try {
      if (toAdd.isNotEmpty) {
        await _adminApiService.bulkAssignPermissions(_selectedRoleId!, toAdd.toList());
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
          content: Text('Permissions updated'),
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

  Map<String, List<Map<String, dynamic>>> get _groupedPermissions {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final p in _permissions) {
      final group = (p['permissionGroup']?.toString().isNotEmpty ?? false)
          ? p['permissionGroup'].toString()
          : 'General';
      map.putIfAbsent(group, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Roles & Permissions'),
      ),
      body: _isLoadingRoles
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Couldn't load roles/permissions: $_error",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                )
              : Column(
                  children: [
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
                              label: Text(role['name']?.toString() ?? ''),
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
                    const Divider(height: 1),
                    Expanded(
                      child: _isLoadingMatrix
                          ? const Center(child: CircularProgressIndicator())
                          : _permissions.isEmpty
                              ? const Center(child: Text('No permissions defined yet.'))
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                  children: _groupedPermissions.entries.map((entry) {
                                    return _buildGroupSection(entry.key, entry.value);
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save changes'),
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
        title: const Text('Discard unsaved changes?'),
        content: const Text('Switching roles will discard your unsaved permission changes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true) {
      _selectRole(newRoleId);
    }
  }

  Widget _buildGroupSection(String group, List<Map<String, dynamic>> permissions) {
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
                title: Text(p['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                subtitle: (p['description']?.toString().isNotEmpty ?? false)
                    ? Text(p['description'].toString(), style: const TextStyle(fontSize: 11))
                    : null,
                value: checked,
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
