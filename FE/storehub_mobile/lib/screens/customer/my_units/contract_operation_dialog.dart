import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/my_unit_model.dart';
import '../../../services/storage_api_service.dart';

class ContractOperationDialog extends StatefulWidget {
  final MyUnitModel unit;
  final bool isExtension;

  const ContractOperationDialog({
    super.key,
    required this.unit,
    required this.isExtension,
  });

  @override
  State<ContractOperationDialog> createState() => _ContractOperationDialogState();
}

class _ContractOperationDialogState extends State<ContractOperationDialog> {
  final StorageApiService _storageService = StorageApiService();
  final TextEditingController _notesController = TextEditingController();
  final _currency = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final _dateFmt = DateFormat('MMM d, yyyy');
  final _dateTimeFmt = DateFormat('MMM d, yyyy • h:mm a');

  int _extraMonths = 3;
  DateTime? _scheduledReturnTime;
  bool _isLoading = false;
  Map<String, dynamic>? _result; 

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledReturnTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _scheduledReturnTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submitAction() async {
    if (!widget.isExtension && _scheduledReturnTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a scheduled return date & time.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> result;
      if (widget.isExtension) {
        result = await _storageService.extendRental(widget.unit.bookingId, _extraMonths);
      } else {
        result = await _storageService.checkoutRental(
          widget.unit.bookingId,
          _scheduledReturnTime!,
          notes: _notesController.text,
        );
      }

      if (!mounted) return;
      setState(() {
        _result = result;
      });
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
    if (_result != null) {
      return _buildResultDialog();
    }
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.isExtension ? 'Extend Rental' : 'Request Checkout'),
      content: SingleChildScrollView(
        child: widget.isExtension ? _buildExtendForm() : _buildCheckoutForm(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitAction,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.isExtension ? 'Extend' : 'Confirm Checkout'),
        ),
      ],
    );
  }

  Widget _buildExtendForm() {
    final unit = widget.unit;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unit ${unit.unitCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (unit.monthlyRate != null)
                Text('Current rate: ${_currency.format(unit.monthlyRate)} / month',
                    style: const TextStyle(fontSize: 12)),
              if (unit.endDate != null)
                Text('Current end date: ${_dateFmt.format(unit.endDate!)}',
                    style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Extend by how many months?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 3, 6, 12].map((m) {
            final selected = _extraMonths == m;
            return ChoiceChip(
              label: Text('+$m mo'),
              selected: selected,
              onSelected: (_) => setState(() => _extraMonths = m),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Custom:', style: TextStyle(fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _extraMonths > 1 ? () => setState(() => _extraMonths--) : null,
            ),
            Text('$_extraMonths month${_extraMonths == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _extraMonths < 36 ? () => setState(() => _extraMonths++) : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'The exact extension fee is calculated by the server and shown after you confirm.',
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildCheckoutForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unit ${widget.unit.unitCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('Choose a date & time to schedule your checkout.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isLoading ? null : _pickScheduledReturnTime,
          icon: const Icon(Icons.event),
          label: Text(
            _scheduledReturnTime == null
                ? 'Select return date & time'
                : _dateTimeFmt.format(_scheduledReturnTime!),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes for the facility staff (optional)',
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildResultDialog() {
    final result = _result!;
    final message = result['message']?.toString();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success),
          SizedBox(width: 8),
          Text('Request confirmed'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null && message.isNotEmpty) ...[
            Text(message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
          ],
          if (widget.isExtension) ...[
            if (result['newEndDate'] != null)
              _resultRow('New end date', result['newEndDate'].toString()),
            if (result['additionalFee'] != null)
              _resultRow(
                'Additional fee charged',
                _currency.format(num.tryParse(result['additionalFee'].toString()) ?? 0),
              ),
            if (result['updatedTotalFee'] != null)
              _resultRow(
                'New total rental fee',
                _currency.format(num.tryParse(result['updatedTotalFee'].toString()) ?? 0),
              ),
          ] else ...[
            if (result['scheduledReturnTime'] != null)
              _resultRow('Scheduled return', result['scheduledReturnTime'].toString()),
            if (result['status'] != null) _resultRow('Status', result['status'].toString()),
          ],
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
