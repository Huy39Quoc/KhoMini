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
  final _renewalWindowController = TextEditingController();
  final _fullRefundHoursController = TextEditingController();
  final _partialRefundHoursController = TextEditingController();
  final _partialRefundPercentController = TextEditingController();
  final _returnNoticeController = TextEditingController();
  final _refundSlaController = TextEditingController();
  final _graceController = TextEditingController();
  final _accessDisableController = TextEditingController();
  final _sealingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final f = widget.facility;
    _nameController = TextEditingController(text: f?['name']?.toString() ?? '');
    _codeController = TextEditingController(text: f?['code']?.toString() ?? '');
    _addressController =
        TextEditingController(text: f?['address']?.toString() ?? '');
    _cityController = TextEditingController(text: f?['city']?.toString() ?? '');
    _phoneController =
        TextEditingController(text: f?['contactPhone']?.toString() ?? '');
    _emailController =
        TextEditingController(text: f?['email']?.toString() ?? '');
    _descriptionController =
        TextEditingController(text: f?['description']?.toString() ?? '');
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
    _renewalWindowController.dispose();
    _fullRefundHoursController.dispose();
    _partialRefundHoursController.dispose();
    _partialRefundPercentController.dispose();
    _returnNoticeController.dispose();
    _refundSlaController.dispose();
    _graceController.dispose();
    _accessDisableController.dispose();
    _sealingController.dispose();
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
          _depositController.text =
              (policy['depositPercentage'] ?? '').toString();
          _lateFeeController.text = (policy['dailyLateFee'] ?? '').toString();
          _minMonthsController.text =
              (policy['minimumRentalMonths'] ?? '').toString();
          _renewalWindowController.text =
              (policy['renewalWindowDays'] ?? '').toString();
          _fullRefundHoursController.text =
              (policy['cancellationFullRefundHours'] ?? '').toString();
          _partialRefundHoursController.text =
              (policy['cancellationPartialRefundHours'] ?? '').toString();
          _partialRefundPercentController.text =
              (policy['cancellationPartialRefundPercent'] ?? '').toString();
          _returnNoticeController.text =
              (policy['returnNoticeDays'] ?? '').toString();
          _refundSlaController.text =
              (policy['depositRefundSlaDays'] ?? '').toString();
          _graceController.text =
              (policy['overdueGraceDays'] ?? '').toString();
          _accessDisableController.text =
              (policy['overdueAccessDisableDays'] ?? '').toString();
          _sealingController.text =
              (policy['overdueSealingDays'] ?? '').toString();
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
      if (_cityController.text.trim().isNotEmpty)
        'city': _cityController.text.trim(),
      if (_phoneController.text.trim().isNotEmpty)
        'contactPhone': _phoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
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

  Widget _policyField(
    TextEditingController controller,
    String label, {
    bool int_ = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: int_
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _savePolicy() async {
    final deposit = double.tryParse(_depositController.text);
    final lateFee = double.tryParse(_lateFeeController.text);
    final minMonths = int.tryParse(_minMonthsController.text);
    final renewalWindow = int.tryParse(_renewalWindowController.text);
    final fullRefundHours = int.tryParse(_fullRefundHoursController.text);
    final partialRefundHours = int.tryParse(_partialRefundHoursController.text);
    final partialRefundPercent =
        double.tryParse(_partialRefundPercentController.text);
    final returnNotice = int.tryParse(_returnNoticeController.text);
    final refundSla = int.tryParse(_refundSlaController.text);
    final grace = int.tryParse(_graceController.text);
    final accessDisable = int.tryParse(_accessDisableController.text);
    final sealing = int.tryParse(_sealingController.text);

    if (deposit == null ||
        lateFee == null ||
        minMonths == null ||
        renewalWindow == null ||
        fullRefundHours == null ||
        partialRefundHours == null ||
        partialRefundPercent == null ||
        returnNotice == null ||
        refundSla == null ||
        grace == null ||
        accessDisable == null ||
        sealing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please fill in valid numbers for the policy fields.')),
      );
      return;
    }

    if (fullRefundHours < partialRefundHours) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Full-refund hours must be greater than or equal to partial-refund hours.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final facilityId = widget.facility!['id'].toString();
    final body = {
      'facilityId': facilityId,
      'depositPercentage': deposit,
      'renewalWindowDays': renewalWindow,
      'cancellationFullRefundHours': fullRefundHours,
      'cancellationPartialRefundHours': partialRefundHours,
      'cancellationPartialRefundPercent': partialRefundPercent,
      'returnNoticeDays': returnNotice,
      'depositRefundSlaDays': refundSla,
      'dailyLateFee': lateFee,
      'overdueGraceDays': grace,
      'overdueAccessDisableDays': accessDisable,
      'overdueSealingDays': sealing,
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
        const SnackBar(
            content: Text('Policy saved'), backgroundColor: AppColors.success),
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
        SnackBar(
            content: Text(
                "Couldn't load users: ${e.toString().replaceAll('Exception: ', '')}")),
      );
      return;
    }
    if (!mounted) return;
    final searchController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final query = searchController.text.trim().toLowerCase();
          final filtered = users.whereType<Map>().where((u) {
            if (u['roleName']?.toString() != 'FACILITY_MANAGER') return false;
            if (query.isEmpty) return true;
            final haystack = [u['fullName'], u['email'], u['username']]
                .whereType<String>()
                .join(' ')
                .toLowerCase();
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
                      const Text('Assign Facility Manager',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchController,
                        onChanged: (_) => setSheet(() {}),
                        decoration: const InputDecoration(
                            hintText: 'Search by name or email',
                            prefixIcon: Icon(Icons.search)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No user with the FACILITY_MANAGER role found. '
                              'Ask an admin to create one first.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13),
                            ),
                          ),
                        )
                      : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final u = filtered[index];
                      final userId = u['id']?.toString() ?? '';
                      final name = u['fullName']?.toString() ??
                          u['username']?.toString() ??
                          '';
                      return ListTile(
                        title: Text(name),
                        subtitle: Text(u['email']?.toString() ?? ''),
                        onTap: () async {
                          try {
                            // Đây là màn "Assign Facility Manager" nên phải gọi endpoint
                            // gán Manager (PUT /managers/{userId}), không phải endpoint
                            // gán Staff như trước đây.
                            await _opsService.assignManagerToFacility(
                                widget.facility!['id'].toString(), userId);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$name assigned as Facility Manager'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text(e
                                      .toString()
                                      .replaceAll('Exception: ', ''))),
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
      appBar:
          AppBar(title: Text(_isEditing ? 'Edit Facility' : 'New Facility')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Facility Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Facility name'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter a name (min 2 characters)'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                    labelText: 'Facility code', hintText: 'e.g. HCM-01'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter a code (min 2 characters)'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Address is required'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City (optional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                    labelText: 'Contact phone (optional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                decoration:
                    const InputDecoration(labelText: 'Email (optional)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(v.trim())) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'INACTIVE', child: Text('Inactive')),
                    DropdownMenuItem(
                        value: 'MAINTENANCE', child: Text('Maintenance')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveFacility,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Save Changes' : 'Create Facility'),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openAssignManagerSheet,
                  icon: const Icon(Icons.person_add_alt, size: 16),
                  label: const Text('Assign Facility Manager'),
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Rental Policy',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  _policy == null
                      ? 'No policy configured yet for this facility.'
                      : 'Editing the existing policy for this facility.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                if (_isLoadingPolicy)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator()))
                else ...[
                  TextFormField(
                    controller: _depositController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Deposit percentage (%)',
                        hintText: 'e.g. 100'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _lateFeeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Daily late fee (\$)', hintText: 'e.g. 5'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _minMonthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Minimum rental months', hintText: 'e.g. 1'),
                  ),
                  const SizedBox(height: 14),
                  _policyField(_renewalWindowController,
                      'Renewal window (days before expiry)', int_: true),
                  const SizedBox(height: 14),
                  _policyField(_fullRefundHoursController,
                      'Full refund if cancelled before start (hours)',
                      int_: true),
                  const SizedBox(height: 14),
                  _policyField(_partialRefundHoursController,
                      'Partial refund if cancelled before start (hours)',
                      int_: true),
                  const SizedBox(height: 14),
                  _policyField(_partialRefundPercentController,
                      'Partial refund percentage (%)'),
                  const SizedBox(height: 14),
                  _policyField(_returnNoticeController,
                      'Return notice (days in advance)',
                      int_: true),
                  const SizedBox(height: 14),
                  _policyField(_refundSlaController,
                      'Deposit refund SLA (days)',
                      int_: true),
                  const SizedBox(height: 14),
                  _policyField(_graceController, 'Overdue grace period (days)',
                      int_: true),
                  const SizedBox(height: 14),
                  _policyField(_accessDisableController,
                      'Disable access after overdue (days)',
                      int_: true),
                  const SizedBox(height: 14),
                  _policyField(_sealingController,
                      'Sealing after overdue (days)',
                      int_: true),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _savePolicy,
                    child:
                        Text(_policy == null ? 'Create Policy' : 'Save Policy'),
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
