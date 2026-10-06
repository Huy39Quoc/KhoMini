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

  // Manager hiện tại của cơ sở (cập nhật ngay sau khi gán)
  String? _managerId;
  String? _managerName;
  String? _managerEmail;

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
  final _managementFeeController = TextEditingController();
  final _discountMonthsController = TextEditingController();
  final _discountPercentController = TextEditingController();

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
    _managerId = f?['managerId']?.toString();
    _managerName = f?['managerName']?.toString();

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
    _managementFeeController.dispose();
    _discountMonthsController.dispose();
    _discountPercentController.dispose();
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
          _managementFeeController.text =
              (policy['managementFeePerMonth'] ?? '').toString();
          _discountMonthsController.text =
              (policy['longTermDiscountMinMonths'] ?? '').toString();
          _discountPercentController.text =
              (policy['longTermDiscountPercent'] ?? '').toString();
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

  InputDecoration _dec(String label, {String? hint, String? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    );
  }

  Widget _policyField(
    TextEditingController controller,
    String label, {
    bool int_ = false,
    String? suffix,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: int_
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: _dec(label, hint: hint, suffix: suffix),
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
    final managementFee = double.tryParse(_managementFeeController.text);
    final discountMonths = int.tryParse(_discountMonthsController.text);
    final discountPercent = double.tryParse(_discountPercentController.text);

    if (deposit == null ||
        managementFee == null ||
        discountMonths == null ||
        discountPercent == null ||
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
      'managementFeePerMonth': managementFee,
      'longTermDiscountMinMonths': discountMonths,
      'longTermDiscountPercent': discountPercent,
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

    // managerId -> tên cơ sở đang quản lý (để Admin thấy ai đang quản lý cơ sở nào)
    final managedFacility = <String, String>{};
    try {
      final facilities = await _service.getFacilities();
      for (final item in facilities.whereType<Map>()) {
        final managerId = item['managerId']?.toString();
        if (managerId != null && managerId.isNotEmpty) {
          managedFacility[managerId] = item['name']?.toString() ?? '';
        }
      }
    } catch (_) {
      // Không có thông tin này thì vẫn cho gán bình thường.
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
                      final managed = managedFacility[userId];
                      final isCurrent = userId == _managerId;
                      return ListTile(
                        title: Text(name),
                        subtitle: Text(
                          '${u['email'] ?? ''}\n'
                          '${managed == null ? 'Not managing any facility' : 'Manages: $managed'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: isCurrent
                            ? const Icon(Icons.check_circle,
                                color: AppColors.success)
                            : null,
                        onTap: () async {
                          try {
                            // Đây là màn "Assign Facility Manager" nên phải gọi endpoint
                            // gán Manager (PUT /managers/{userId}), không phải endpoint
                            // gán Staff như trước đây.
                            await _opsService.assignManagerToFacility(
                                widget.facility!['id'].toString(), userId);
                            if (mounted) {
                              setState(() {
                                _managerId = userId;
                                _managerName = name;
                                _managerEmail = u['email']?.toString();
                              });
                            }
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


  static const SizedBox _gap = SizedBox(height: 14);

  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _pair(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }

  Widget _buildManagerCard() {
    final hasManager = _managerName != null && _managerName!.isNotEmpty;

    return _section(
      icon: Icons.manage_accounts_outlined,
      title: 'Facility manager',
      subtitle: 'The person responsible for operating this facility.',
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: hasManager
                  ? AppColors.primaryContainer
                  : AppColors.surfaceContainerHigh,
              child: Icon(
                hasManager ? Icons.person : Icons.person_off_outlined,
                color: hasManager ? Colors.white : AppColors.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasManager ? _managerName! : 'No manager assigned',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (hasManager &&
                      _managerEmail != null &&
                      _managerEmail!.isNotEmpty)
                    Text(
                      _managerEmail!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
        _gap,
        OutlinedButton.icon(
          onPressed: _openAssignManagerSheet,
          icon: const Icon(Icons.person_add_alt, size: 16),
          label: Text(hasManager ? 'Change manager' : 'Assign manager'),
        ),
      ],
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(
              icon: Icons.business_outlined,
              title: 'Facility details',
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _dec('Facility name'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter a name (min 2 characters)'
                      : null,
                ),
                _gap,
                TextFormField(
                  controller: _codeController,
                  decoration: _dec('Facility code', hint: 'e.g. HCM-01'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter a code (min 2 characters)'
                      : null,
                ),
                _gap,
                TextFormField(
                  controller: _addressController,
                  decoration: _dec('Address'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Address is required'
                      : null,
                ),
                _gap,
                TextFormField(
                  controller: _cityController,
                  decoration: _dec('City (optional)'),
                ),
                if (_isEditing) ...[
                  _gap,
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _dec('Status'),
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
              ],
            ),
            _section(
              icon: Icons.contact_phone_outlined,
              title: 'Contact',
              children: [
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _dec('Contact phone (optional)'),
                ),
                _gap,
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('Email (optional)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                _gap,
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: _dec('Description (optional)'),
                ),
              ],
            ),
            if (_isEditing) _buildManagerCard(),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyTab() {
    if (_isLoadingPolicy) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2),
            child: Text(
              _policy == null
                  ? 'No policy configured yet for this facility.'
                  : 'Editing the existing policy for this facility.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
          ),
          _section(
            icon: Icons.payments_outlined,
            title: 'Deposit & fees',
            children: [
              _pair(
                _policyField(_depositController, 'Deposit', suffix: '%'),
                _policyField(_lateFeeController, 'Daily late fee', suffix: 'VND'),
              ),
              _gap,
              _pair(
                _policyField(_minMonthsController, 'Min. rental',
                    int_: true, suffix: 'months'),
                _policyField(_refundSlaController, 'Deposit refund',
                    int_: true, suffix: 'days'),
              ),
            ],
          ),
          _section(
            icon: Icons.autorenew,
            title: 'Renewal & return',
            children: [
              _pair(
                _policyField(_renewalWindowController, 'Renewal window',
                    int_: true, suffix: 'days'),
                _policyField(_returnNoticeController, 'Return notice',
                    int_: true, suffix: 'days'),
              ),
            ],
          ),
          _section(
            icon: Icons.sell_outlined,
            title: 'Extra fee & discount',
            subtitle:
                'Management fee 0 = fee waived. Discount 0 months = no discount.',
            children: [
              _policyField(_managementFeeController, 'Management fee',
                  suffix: 'VND / month'),
              _gap,
              _pair(
                _policyField(_discountMonthsController, 'Discount from',
                    int_: true, suffix: 'months'),
                _policyField(_discountPercentController, 'Rent discount',
                    suffix: '%'),
              ),
            ],
          ),
          _section(
            icon: Icons.event_busy_outlined,
            title: 'Cancellation refund',
            subtitle: 'Time before the rental start date.',
            children: [
              _pair(
                _policyField(_fullRefundHoursController, 'Full refund',
                    int_: true, suffix: 'hours'),
                _policyField(_partialRefundHoursController, 'Partial refund',
                    int_: true, suffix: 'hours'),
              ),
              _gap,
              _policyField(_partialRefundPercentController,
                  'Partial refund amount',
                  suffix: '%'),
            ],
          ),
          _section(
            icon: Icons.warning_amber_rounded,
            title: 'Overdue handling',
            subtitle: 'Days after the rental end date.',
            children: [
              _policyField(_graceController, 'Grace period',
                  int_: true, suffix: 'days'),
              _gap,
              _pair(
                _policyField(_accessDisableController, 'Disable access',
                    int_: true, suffix: 'days'),
                _policyField(_sealingController, 'Sealing',
                    int_: true, suffix: 'days'),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _savePolicy,
            child: Text(_policy == null ? 'Create Policy' : 'Save Policy'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('New Facility')),
        body: _buildDetailsTab(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Edit Facility'),
          bottom: const TabBar(
            labelColor: AppColors.secondaryContainer,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.secondaryContainer,
            tabs: [Tab(text: 'Details'), Tab(text: 'Rental Policy')],
          ),
        ),
        body: TabBarView(
          children: [_buildDetailsTab(), _buildPolicyTab()],
        ),
      ),
    );
  }
}
