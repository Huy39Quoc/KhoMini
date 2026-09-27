import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/storage_api_service.dart';
import '../../../services/ticket_api_service.dart';

class CreateTicketScreen extends StatefulWidget {
  /// Optionally pre-select which rented unit this ticket is about (e.g. when
  /// opened from a "Report an issue" action on a specific unit card).
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

/// Category values match com.storehub.enums.TicketCategory on the BE
/// exactly - sending anything else makes the BE reject the request with a
/// 400 (invalid enum value).
const Map<String, _CategoryInfo> _kCategories = {
  'PIN_CODE': _CategoryInfo('Access PIN issue', Icons.pin_outlined),
  'LOCK_ISSUE': _CategoryInfo('Lock / door issue', Icons.lock_outline),
  'FACILITY_DAMAGE': _CategoryInfo('Facility damage', Icons.report_problem_outlined),
  'PAYMENT_ISSUE': _CategoryInfo('Payment issue', Icons.payments_outlined),
  'OTHER': _CategoryInfo('Other', Icons.more_horiz),
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

  bool _isLoading = false;
  bool _isLoadingUnits = true;
  List<Map<String, String>> _units = []; // [{bookingId, label}]
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
            final unitCode = u['unitCode']?.toString() ?? 'Unit';
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

    setState(() {
      _isLoading = true;
    });

    try {
      await _ticketApiService.createTicket(
        _selectedCategory,
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _selectedBookingId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Support ticket submitted successfully!'),
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
      appBar: AppBar(title: const Text('Report an Issue')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Related unit picker
                const Text('Related unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text(
                  'Optional - pick a unit if this issue is about a specific storage unit',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                _buildUnitPicker(),
                if (_selectedBookingId != null && _selectedUnitLabel != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This ticket will reference: $_selectedUnitLabel',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Category
                const Text('Issue category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                      ),
                      label: Text(entry.value.label),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Title
                const Text('Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    hintText: 'Short summary, e.g. "PIN code not working"',
                    helperText: 'Required, up to 255 characters',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Title is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue in detail, including when it started...',
                    helperText: 'Required - the more detail, the faster we can help',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Description is required';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitTicket,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Submitting...' : 'Submit Ticket'),
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
          "Couldn't load your units: $_unitsError",
          style: const TextStyle(color: AppColors.error, fontSize: 12),
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
            child: Text('General inquiry (no specific unit)'),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('General inquiry (no specific unit)'),
              ),
            ),
            ..._units.map(
              (u) => DropdownMenuItem<String?>(
                value: u['bookingId'],
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(u['label'] ?? 'Unit'),
                ),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedBookingId = value;
              _selectedUnitLabel =
                  _units.firstWhere((u) => u['bookingId'] == value, orElse: () => {})['label'];
            });
          },
        ),
      ),
    );
  }
}
