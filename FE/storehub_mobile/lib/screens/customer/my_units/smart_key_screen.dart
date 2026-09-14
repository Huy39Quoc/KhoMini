import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/smart_access_model.dart';
import '../../../services/storage_api_service.dart';

class SmartKeyScreen extends StatefulWidget {
  final String bookingId;
  final String unitCode;

  const SmartKeyScreen(
      {super.key, required this.bookingId, required this.unitCode});

  @override
  State<SmartKeyScreen> createState() => _SmartKeyScreenState();
}

class _SmartKeyScreenState extends State<SmartKeyScreen> {
  final StorageApiService _storageService = StorageApiService();
  late Future<SmartAccessModel> _accessFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _accessFuture = _storageService.getSmartAccess(widget.bookingId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Access - ${widget.unitCode}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<SmartAccessModel>(
        future: _accessFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final data = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('Gate Access QR Token',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        QrImageView(
                            data: data.qrCodeToken.isNotEmpty
                                ? data.qrCodeToken
                                : 'STOREHUB-ACCESS',
                            version: QrVersions.auto,
                            size: 200),
                        const SizedBox(height: 8),
                        const Text('Scan at facility gate barrier',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('Unit Electronic Lock PIN',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(data.accessPin,
                            style: const TextStyle(
                                fontSize: 36,
                                letterSpacing: 8,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showPinDialog(data.accessPin),
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Change PIN'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPinDialog(String currentPin) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update 6-digit PIN'),
        content: TextField(
          controller: controller,
          maxLength: 6,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              hintText: 'Enter 6 digits', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.length != 6) {
                return;
              }
              Navigator.pop(ctx);
              await _storageService.updatePin(
                  widget.bookingId, controller.text);
              if (mounted) {
                _load();
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
