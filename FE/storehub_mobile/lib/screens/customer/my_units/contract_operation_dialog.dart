import 'package:flutter/material.dart';
import '../../../services/storage_api_service.dart';

class ContractOperationDialog extends StatefulWidget {
  final String contractId;
  final String unitNumber;

  const ContractOperationDialog({
    super.key,
    required this.contractId,
    required this.unitNumber,
  });

  @override
  State<ContractOperationDialog> createState() =>
      _ContractOperationDialogState();
}

class _ContractOperationDialogState extends State<ContractOperationDialog> {
  final StorageApiService _storageService = StorageApiService();
  bool _isLoading = false;
  int _extensionMonths = 1;

  void _handleExtend() async {
    setState(() => _isLoading = true);
    try {
      bool success = await _storageService.extendRental(
          widget.contractId, _extensionMonths);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Contract extended successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Extension failed: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleCheckout() async {
    setState(() => _isLoading = true);
    try {
      bool success = await _storageService.checkoutRental(widget.contractId);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unit return requested successfully!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Checkout failed: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Manage Contract - Unit #${widget.unitNumber}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'Choose an operation to perform on your active storage contract:'),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue:
                _extensionMonths, // Sửa thành initialValue để hết warning deprecated
            decoration:
                const InputDecoration(labelText: 'Extension Duration (Months)'),
            items: [1, 3, 6, 12]
                .map(
                    (m) => DropdownMenuItem(value: m, child: Text('$m Months')))
                .toList(),
            onChanged: (val) => setState(() => _extensionMonths = val ?? 1),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: _isLoading ? null : _handleCheckout,
                child: const Text('Request Return'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _handleExtend,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Extend Now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
