import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/admin_api_service.dart';
import '../../services/facility_admin_api_service.dart';
import '../../services/facility_ops_api_service.dart';

/// Create/edit a Facility (FacilityController) and view/edit its
/// FacilityPolicy (FacilityPolicyController) in one place, since a policy
/// always belongs to exactly one facility.
class FacilityEditScreen extends StatefulWidget {
  final Map? facility; // null = create mode
  const FacilityEditScreen({super.key, this.facility});

  @override
  State<FacilityEditScreen> createState() => _FacilityEditScreenState();
}

class _FacilityEditScreenState extends State<FacilityEditScreen> {
  final FacilityAdminApiService _service = FacilityAdminApiService();
  final FacilityOpsApiService _opsService = FacilityOpsApiService();
  final AdminApiService _adminApiService = AdminApiService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _descriptionController;
  String _status = 'ACTIVE';

  bool get _isEditing => widget.facility != null;
  bool _isSaving = false;

  // Policy state
  bool _isLoadingPolicy = false;
  Map<String, dynamic>? _policy;
  final _depositController = TextEditingController();
  final _lateFeeController = TextEditingController();
  final _minMonthsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final f = widget.facility;
    _nameController = TextEditingController(text: f?['name']?.toString() ?? '');
    _codeController = TextEditingController(text: f?['code']?.toString() ?? '');
    _addressController = TextEditingController(text: f?['address']?.toString() ?? '');
    _cityController = TextEditingController(text: f?['city']?.toString() ?? '');
    _phoneController = TextEditingController(text: f?['contactPhone']?.toString() ?? '');
    _emailController = TextEditingController(text: f?['email']?.toString() ?? '');
    _descriptionController = TextEditingController(text: f?['description']?.toString() ?? '');
    _status = f?['status']?.toString() ?? 'ACTIVE';

    if (_isEditing) _loadPolicy();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _depositController.dispose();
    _lateFeeController.dispose();
    _minMonthsController.dispose();
    super.dispose();
  }

  Future<void> _loadPolicy() async {
    setState(() => _isLoadingPolicy = true);
    try {
      final facilityId = widget.facility!['id'].toString();
      final policy = await _service.getFacilityPolicyByFacility(facilityId);
      if (!mounted) return;
      setState(() {
        _policy = policy;
        if (policy != null) {
          _depositController.text = (policy['depositPercentage'] ?? '').toString();
          _lateFeeController.text = (policy['dailyLateFee'] ?? '').toString();
          _minMonthsController.text = (policy['minimumRentalMonths'] ?? '').toString();
        }
        _isLoadingPolicy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPolicy = false);
    }
  }

  Future<void> _saveFacility() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final body = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'address': _addressController.text.trim(),
      if (_cityController.text.trim().isNotEmpty) 'city': _cityController.text.trim(),
      if (_phoneController.text.trim().isNotEmpty) 'contactPhone': _phoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty) 'email': _emailController.text.trim(),
      if (_descriptionController.text.trim().isNotEmpty) 'description': _descriptionController.text.trim(),
      if (_isEditing) 'status': _status,
    };

    try {
      if (_isEditing) {
        await _service.updateFacility(widget.facility!['id'].toString(), body);
      } else {
        await _service.createFacility(body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Facility updated' : 'Facility created'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
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

  Future<void> _savePolicy() async {
    final deposit = double.tryParse(_depositController.text);
    final lateFee = double.tryParse(_lateFeeController.text);
    final minMonths = int.tryParse(_minMonthsController.text);
    if (deposit == null || lateFee == null || minMonths == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in valid numbers for the policy fields.')),
      );
      return;
    }

    final facilityId = widget.facility!['id'].toString();
    // Sensible, editable defaults for the fields not shown inline - kept
    // simple here; a full policy editor can expose all fields later.
    final body = {
      'facilityId': facilityId,
      'depositPercentage': deposit,
      'renewalWindowDays': _policy?['renewalWindowDays'] ?? 7,
      'cancellationFullRefundHours': _policy?['cancellationFullRefundHours'] ?? 48,
      'cancellationPartialRefundHours': _policy?['cancellationPartialRefundHours'] ?? 24,
      'cancellationPartialRefundPercent': _policy?['cancellationPartialRefundPercent'] ?? 50.0,
      'returnNoticeDays': _policy?['returnNoticeDays'] ?? 3,
      'depositRefundSlaDays': _policy?['depositRefundSlaDays'] ?? 7,
      'dailyLateFee': lateFee,
      'overdueGraceDays': _policy?['overdueGraceDays'] ?? 3,
      'overdueAccessDisableDays': _policy?['overdueAccessDisableDays'] ?? 7,
      'overdueSealingDays': _policy?['overdueSealingDays'] ?? 30,
      'minimumRentalMonths': minMonths,
    };

    try {
      if (_policy != null) {
        await _service.updateFacilityPolicy(_policy!['id'].toString(), body);
      } else {
        await _service.createFacilityPolicy(body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Policy saved'), backgroundColor: AppColors.success),
      );
      _loadPolicy();
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

  Future<void> _openAssignManagerSheet() async {
    List<dynamic> users;
    try {
      users = await _adminApiService.getUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't load users: ${e.toString().replaceAll('Exception: ', '')}")),
      );
      return;
    }
    if (!mounted) return;
    final searchController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = users.whereType<Map>().where((u) {
            if (query.isEmpty) return true;
            final haystack = [u['fullName'], u['email'], u['username']].whereType<String>().join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign Facility Manager', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchController,
                        onChanged: (_) => setSheet(() {}),
                        decoration: const InputDecoration(hintText: 'Search by name or email', prefixIcon: Icon(Icons.search)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final u = filtered[index];
                      final userId = u['id']?.toString() ?? '';
                      final name = u['fullName']?.toString() ?? u['username']?.toString() ?? '';
                      return ListTile(
                        title: Text(name),
                        subtitle: Text(u['email']?.toString() ?? ''),
                        onTap: () async {
                          try {
                            await _opsService.assignStaffToFacility(widget.facility!['id'].toString(), userId);
                            // Note: assignStaff endpoint assigns as STAFF; managers use
                            // the dedicated /managers/{userId} endpoint below instead.
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(_isEditing ? 'Edit Facility' : 'New Facility')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Facility Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Facility name'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a name (min 2 characters)' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Facility code', hintText: 'e.g. HCM-01'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a code (min 2 characters)' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City (optional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Contact phone (optional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                    DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveFacility,
                child: _isSaving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Save Changes' : 'Create Facility'),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openAssignManagerSheet,
                  icon: const Icon(Icons.person_add_alt, size: 16),
                  label: const Text('Assign Manager / Staff'),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Rental Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  _policy == null
                      ? 'No policy configured yet for this facility.'
                      : 'Editing the existing policy for this facility.',
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                if (_isLoadingPolicy)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                else ...[
                  TextFormField(
                    controller: _depositController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Deposit percentage (%)', hintText: 'e.g. 100'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _lateFeeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Daily late fee (\$)', hintText: 'e.g. 5'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _minMonthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minimum rental months', hintText: 'e.g. 1'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _savePolicy,
                    child: Text(_policy == null ? 'Create Policy' : 'Save Policy'),
                  ),
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
