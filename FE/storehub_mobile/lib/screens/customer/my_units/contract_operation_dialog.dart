import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/storage_api_service.dart';

class ContractOperationDialog extends StatelessWidget {
  final String bookingId;
  final VoidCallback onComplete;

  const ContractOperationDialog(
      {super.key, required this.bookingId, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final StorageApiService storageService = StorageApiService();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Contract Management',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.more_time, color: AppColors.primary),
            title: const Text('Extend Rental Contract'),
            subtitle: const Text('Add extra months to current storage'),
            onTap: () {
              Navigator.pop(context);
              _showExtend(context, storageService);
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: AppColors.accent),
            title: const Text('Request Checkout & Handover'),
            subtitle: const Text('Schedule return inspection & refund deposit'),
            onTap: () {
              Navigator.pop(context);
              _showCheckout(context, storageService);
            },
          ),
        ],
      ),
    );
  }

  void _showExtend(
      BuildContext parentContext, StorageApiService storageService) {
    int months = 1;
    showDialog(
      context: parentContext,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Extend Contract'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Months to add: $months',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: months.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                onChanged: (v) => setState(() => months = v.toInt()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                try {
                  await storageService.extendRental(bookingId, months);
                  onComplete();
                } catch (e) {
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckout(
      BuildContext parentContext, StorageApiService storageService) {
    final note = TextEditingController();
    showDialog(
      context: parentContext,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Schedule Handover'),
        content: TextField(
            controller: note,
            decoration: const InputDecoration(
                labelText: 'Handover Notes', border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final returnTime = DateTime.now()
                    .add(const Duration(days: 3))
                    .toIso8601String();
                await storageService.requestCheckout(
                    bookingId, returnTime, note.text);
                onComplete();
              } catch (e) {
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
