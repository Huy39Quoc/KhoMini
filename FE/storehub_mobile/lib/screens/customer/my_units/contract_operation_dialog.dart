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
  bool _isLoading = false;

  void _submitAction() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isExtension) {
        final int months = int.tryParse(_monthsController.text.trim()) ?? 1;
        await _storageService.extendRental(widget.bookingId, months);
      } else {
        await _storageService.checkoutRental(widget.bookingId);
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
          : const Text('Are you sure you want to request a unit checkout?'),
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
