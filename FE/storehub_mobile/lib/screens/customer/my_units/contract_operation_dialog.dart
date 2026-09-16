import 'package:flutter/material.dart';
import '../../../../services/storage_api_service.dart';

class ContractOperationDialog extends StatefulWidget {
  final String bookingId;
  final bool isExtension;

  const ContractOperationDialog({
    super.key,
    required this.bookingId,
    required this.isExtension,
  });

  @override
  State<ContractOperationDialog> createState() =>
      _ContractOperationDialogState();
}

class _ContractOperationDialogState extends State<ContractOperationDialog> {
  final StorageApiService _storageService = StorageApiService();
  final TextEditingController _monthsController =
      TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();
  DateTime? _scheduledReturnTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _monthsController.dispose();
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
      _scheduledReturnTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submitAction() async {
    // Checkout bắt buộc phải chọn thời gian hẹn trả kho (BE yêu cầu và
    // phải nằm trong tương lai).
    if (!widget.isExtension && _scheduledReturnTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a scheduled return date & time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isExtension) {
        final int months = int.tryParse(_monthsController.text.trim()) ?? 1;
        await _storageService.extendRental(widget.bookingId, months);
      } else {
        await _storageService.checkoutRental(
          widget.bookingId,
          _scheduledReturnTime!,
          notes: _notesController.text,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Operation failed: ${e.toString()}'),
            backgroundColor: Colors.red),
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
    return AlertDialog(
      title: Text(
          widget.isExtension ? 'Extend Rental Contract' : 'Checkout Request'),
      content: widget.isExtension
          ? TextField(
              controller: _monthsController,
              decoration: const InputDecoration(
                  labelText: 'Number of months to extend'),
              keyboardType: TextInputType.number,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Please choose a date & time to schedule your checkout.'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickScheduledReturnTime,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _scheduledReturnTime == null
                        ? 'Select return date & time'
                        : _scheduledReturnTime!
                            .toString()
                            .substring(0, 16)
                            .replaceFirst('.000', ''),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
              ],
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
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.isExtension ? 'Extend' : 'Confirm Checkout'),
        ),
      ],
    );
  }
}
