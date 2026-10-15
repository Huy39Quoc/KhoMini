import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  late final TextEditingController _imageUrlController;
  String _status = 'ACTIVE';
  bool _airConditioned24h = false;
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 20, minute: 0);

  bool get _isEditing => widget.facility != null;
  bool _isSaving = false;
  List<String> _imageUrls = [];
  bool _isUploadingImage = false;

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
  final _maxAdvanceReservationDaysController = TextEditingController();

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
    _imageUrlController =
        TextEditingController(text: f?['imageUrl']?.toString() ?? '');

    if (f != null && f['images'] is List) {
      _imageUrls = (f['images'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (f != null &&
        f['images'] is String &&
        (f['images'] as String).isNotEmpty) {
      _imageUrls = (f['images'] as String)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (_imageUrls.isEmpty && _imageUrlController.text.trim().isNotEmpty) {
      _imageUrls.add(_imageUrlController.text.trim());
    }

    _status = f?['status']?.toString() ?? 'ACTIVE';
    _airConditioned24h = f?['airConditioned24h'] == true;
    _openTime = _parseTime(f?['openTime']) ?? _openTime;
    _closeTime = _parseTime(f?['closeTime']) ?? _closeTime;
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
    _imageUrlController.dispose();
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
    _maxAdvanceReservationDaysController.dispose();
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
          _graceController.text = (policy['overdueGraceDays'] ?? '').toString();
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
          _maxAdvanceReservationDaysController.text =
              (policy['maxAdvanceReservationDays'] ?? '14').toString();
        }
        _isLoadingPolicy = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPolicy = false);
    }
  }

  Future<void> _pickAndUploadMultipleImages() async {
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(imageQuality: 85);
      if (pickedList.isEmpty) return;

      setState(() {
        _isUploadingImage = true;
      });

      final paths = pickedList.map((x) => x.path).toList();
      final uploadedUrls = await _service.uploadFacilityImages(paths);

      if (!mounted) return;
      setState(() {
        for (final url in uploadedUrls) {
          if (url.isNotEmpty && !_imageUrls.contains(url)) {
            _imageUrls.add(url);
          }
        }
        if (_imageUrls.isNotEmpty) {
          _imageUrlController.text = _imageUrls.first;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tải ảnh lên thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tải ảnh thất bại: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _pickAndUploadFromCamera() async {
    try {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final uploadedUrl = await _service.uploadFacilityImage(
        picked.path,
        facilityId: widget.facility?['id']?.toString(),
      );

      if (!mounted) return;
      setState(() {
        if (uploadedUrl.isNotEmpty && !_imageUrls.contains(uploadedUrl)) {
          _imageUrls.add(uploadedUrl);
        }
        if (_imageUrls.isNotEmpty) {
          _imageUrlController.text = _imageUrls.first;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tải ảnh lên thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Tải ảnh thất bại: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      _imageUrls.removeAt(index);
      if (_imageUrls.isNotEmpty) {
        _imageUrlController.text = _imageUrls.first;
      } else {
        _imageUrlController.clear();
      }
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thêm ảnh cơ sở kho',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primaryContainer),
                title: const Text('Chọn nhiều ảnh từ thư viện'),
                subtitle:
                    const Text('Có thể chọn cùng lúc nhiều ảnh từ thiết bị'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadMultipleImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.primaryContainer),
                title: const Text('Chụp ảnh mới bằng camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadFromCamera();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFacility() async {
    if (_isUploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đợi ảnh tải lên hoàn tất...'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final opens = _openTime.hour * 60 + _openTime.minute;
    final closes = _closeTime.hour * 60 + _closeTime.minute;
    if (opens >= closes) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Giờ đóng cửa phải sau giờ mở cửa trong cùng một ngày.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
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
      'imageUrl': _imageUrls.isNotEmpty
          ? _imageUrls.first
          : _imageUrlController.text.trim(),
      'images': _imageUrls,
      if (_isEditing) 'status': _status,
      'airConditioned24h': _airConditioned24h,
      'openTime': _formatTime(_openTime),
      'closeTime': _formatTime(_closeTime),
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

  TimeOfDay? _parseTime(dynamic value) {
    final parts = value?.toString().split(':');
    if (parts == null || parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickFacilityTime({required bool opening}) async {
    final chosen = await showTimePicker(
      context: context,
      initialTime: opening ? _openTime : _closeTime,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (opening) {
        _openTime = chosen;
      } else {
        _closeTime = chosen;
      }
    });
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
    final maxAdvanceDays = int.tryParse(_maxAdvanceReservationDaysController.text) ?? 14;

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
      'maxAdvanceReservationDays': maxAdvanceDays,
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
                                      widget.facility!['id'].toString(),
                                      userId);
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
                                      content: Text(
                                          '$name assigned as Facility Manager'),
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
                SwitchListTile(
                  title: const Text('Máy lạnh 24/7'),
                  subtitle: const Text(
                      'Bật khi toàn bộ ngăn tại cơ sở đều có máy lạnh 24/7.'),
                  value: _airConditioned24h,
                  onChanged: (value) =>
                      setState(() => _airConditioned24h = value),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickFacilityTime(opening: true),
                        icon: const Icon(Icons.schedule),
                        label: Text('Mở ${_openTime.format(context)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickFacilityTime(opening: false),
                        icon: const Icon(Icons.schedule),
                        label: Text('Đóng ${_closeTime.format(context)}'),
                      ),
                    ),
                  ],
                ),
                _gap,
                const Text(
                  'Hình ảnh cơ sở kho',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (_imageUrls.isEmpty)
                  GestureDetector(
                    onTap: _isUploadingImage ? null : _showImageSourceSheet,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 44,
                                    color: AppColors.primaryContainer
                                        .withValues(alpha: 0.8)),
                                const SizedBox(height: 8),
                                const Text(
                                  'Bấm để chọn nhiều ảnh từ máy hoặc chụp ảnh',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (_isUploadingImage)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                        color: Colors.white),
                                    SizedBox(height: 10),
                                    Text(
                                      'Đang tải ảnh lên...',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Đã tải lên ${_imageUrls.length} ảnh',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryContainer),
                          ),
                          TextButton.icon(
                            onPressed: _isUploadingImage
                                ? null
                                : _showImageSourceSheet,
                            icon:
                                const Icon(Icons.add_photo_alternate, size: 16),
                            label: const Text('Thêm ảnh',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageUrls.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, idx) {
                            if (idx == _imageUrls.length) {
                              return GestureDetector(
                                onTap: _isUploadingImage
                                    ? null
                                    : _showImageSourceSheet,
                                child: Container(
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHigh
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.border,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          size: 28,
                                          color: AppColors.primaryContainer),
                                      SizedBox(height: 6),
                                      Text(
                                        '+ Thêm',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.primaryContainer,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final url = _imageUrls[idx];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.black12,
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                        child: Icon(Icons.broken_image_outlined,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                                if (idx == 0)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Ảnh chính',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImageAt(idx),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade700
                                            .withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      if (_isUploadingImage) ...[
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Đang tải ảnh lên...',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryContainer)),
                          ],
                        ),
                      ],
                    ],
                  ),
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
                _policyField(_lateFeeController, 'Daily late fee',
                    suffix: 'VND'),
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
            title: 'Booking & renewal window',
            children: [
              _pair(
                _policyField(_maxAdvanceReservationDaysController,
                    'Max advance booking',
                    int_: true, suffix: 'days', hint: 'e.g. 14'),
                _policyField(_renewalWindowController, 'Renewal window',
                    int_: true, suffix: 'days'),
              ),
              _gap,
              _policyField(_returnNoticeController, 'Return notice',
                  int_: true, suffix: 'days'),
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
              _policyField(
                  _partialRefundPercentController, 'Partial refund amount',
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
