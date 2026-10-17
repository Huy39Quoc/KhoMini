import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/storage_api_service.dart';
import '../../../services/ticket_api_service.dart';
import '../../../widgets/photo_preview_dialog.dart';

class CreateTicketScreen extends StatefulWidget {
  final String? preselectedBookingId;
  final String? preselectedUnitLabel;

  const CreateTicketScreen({
    super.key,
    this.preselectedBookingId,
    this.preselectedUnitLabel,
  });

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

const Map<String, _CategoryInfo> _kCategories = {
  'PIN_CODE': _CategoryInfo('Sự cố mã PIN', Icons.pin_outlined),
  'LOCK_ISSUE': _CategoryInfo('Sự cố khóa / cửa', Icons.lock_outline),
  'FACILITY_DAMAGE':
      _CategoryInfo('Hư hỏng cơ sở', Icons.report_problem_outlined),
  'PAYMENT_ISSUE': _CategoryInfo('Sự cố thanh toán', Icons.payments_outlined),
  'OTHER': _CategoryInfo('Khác', Icons.more_horiz),
};

class _CategoryInfo {
  final String label;
  final IconData icon;
  const _CategoryInfo(this.label, this.icon);
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final TicketApiService _ticketApiService = TicketApiService();
  final StorageApiService _storageApiService = StorageApiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategory = 'LOCK_ISSUE';
  String? _selectedBookingId;
  String? _selectedUnitLabel;
  List<File> _selectedFiles = [];

  bool _isLoading = false;
  bool _isLoadingUnits = true;
  List<Map<String, String>> _units = [];
  String? _unitsError;

  @override
  void initState() {
    super.initState();
    _selectedBookingId = widget.preselectedBookingId;
    _selectedUnitLabel = widget.preselectedUnitLabel;
    _loadUnits();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final raw = await _storageApiService.getMyRentedUnits();
      final units = raw
          .whereType<Map>()
          .map((u) {
            final bookingId = u['bookingId']?.toString() ?? '';
            final unitCode = u['unitCode']?.toString() ?? 'Ngăn kho';
            final facility = u['facilityName']?.toString() ?? '';
            return {
              'bookingId': bookingId,
              'label': facility.isNotEmpty ? '$unitCode • $facility' : unitCode,
            };
          })
          .where((u) => u['bookingId']!.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _units = units;
        _isLoadingUnits = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unitsError = e.toString().replaceAll('Exception: ', '');
        _isLoadingUnits = false;
      });
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBookingId == null || _selectedBookingId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngăn kho liên quan đến sự cố.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> uploadedUrls = [];
      if (_selectedFiles.isNotEmpty) {
        uploadedUrls = await _ticketApiService.uploadTicketPhotos(
          _selectedFiles.map((f) => f.path).toList(),
        );
      }

      await _ticketApiService.createTicket(
        _selectedCategory,
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _selectedBookingId!,
        photos: uploadedUrls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi yêu cầu hỗ trợ!'),
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
      appBar: AppBar(title: const Text('Báo sự cố')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Ngăn kho liên quan',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text(
                  'Chọn ngăn kho đang thuê liên quan đến sự cố',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                _buildUnitPicker(),
                if (_selectedBookingId != null &&
                    _selectedUnitLabel != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Yêu cầu sẽ gắn với: $_selectedUnitLabel',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                const Text('Loại sự cố',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kCategories.entries.map((entry) {
                    final isSelected = _selectedCategory == entry.key;
                    return ChoiceChip(
                      avatar: Icon(
                        entry.value.icon,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : AppColors.onSurfaceVariant,
                      ),
                      label: Text(entry.value.label),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                const Text('Tiêu đề',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    hintText: 'Tóm tắt ngắn, VD: "Mã PIN không hoạt động"',
                    helperText: 'Bắt buộc, tối đa 255 ký tự',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Vui lòng nhập tiêu đề';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text('Mô tả',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText:
                        'Mô tả chi tiết sự cố, bao gồm thời điểm bắt đầu...',
                    helperText:
                        'Bắt buộc - càng chi tiết, chúng tôi xử lý càng nhanh',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Vui lòng nhập mô tả';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text('Ảnh bằng chứng (không bắt buộc)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text(
                  'Đính kèm ảnh (dột nước, nứt tường, hỏng khóa...) để nhân viên chuẩn bị dụng cụ và xử lý nhanh hơn.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                EvidencePhotoPicker(
                  selectedFiles: _selectedFiles,
                  enabled: !_isLoading,
                  onFilesChanged: (files) =>
                      setState(() => _selectedFiles = files),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitTicket,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Đang gửi...' : 'Gửi yêu cầu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitPicker() {
    if (_isLoadingUnits) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    if (_unitsError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Không tải được kho của bạn: $_unitsError",
          style: const TextStyle(color: AppColors.error, fontSize: 12),
        ),
      );
    }

    if (_units.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Bạn cần có kho đang thuê để gửi yêu cầu hỗ trợ.',
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedBookingId,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          borderRadius: BorderRadius.circular(12),
          hint: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Chọn ngăn kho liên quan đến sự cố'),
          ),
          items: [
            ..._units.map(
              (u) => DropdownMenuItem<String?>(
                value: u['bookingId'],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(u['label'] ?? 'Ngăn kho'),
                ),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedBookingId = value;
              _selectedUnitLabel = _units.firstWhere(
                  (u) => u['bookingId'] == value,
                  orElse: () => {})['label'];
            });
          },
        ),
      ),
    );
  }
}
