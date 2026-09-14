import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/my_unit_model.dart';
import '../../../services/auth_api_service.dart';
import '../../../services/storage_api_service.dart';
import '../../auth/login_screen.dart';
import '../tickets/ticket_list_screen.dart';
import 'contract_operation_dialog.dart';
import 'smart_key_screen.dart';

class MyRentedUnitsScreen extends StatefulWidget {
  const MyRentedUnitsScreen({super.key});

  @override
  State<MyRentedUnitsScreen> createState() => _MyRentedUnitsScreenState();
}

class _MyRentedUnitsScreenState extends State<MyRentedUnitsScreen> {
  final StorageApiService _storageService = StorageApiService();
  late Future<List<MyUnitModel>> _unitsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _unitsFuture = _storageService.getMyRentedUnits();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Active Storage Units'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TicketListScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthApiService().logout();
              if (context.mounted) {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<MyUnitModel>>(
        future: _unitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(
                child: Text('No active storage rentals found.'));
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _buildUnitCard(list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnitCard(MyUnitModel u) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final active = u.hasActiveAccess;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    u.unitCode.isNotEmpty
                        ? 'Unit: ${u.unitCode}'
                        : 'Pending Handover',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Chip(
                    label: Text(u.status,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor:
                        active ? AppColors.success : AppColors.accent),
              ],
            ),
            Text(u.facilityName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(u.facilityAddress,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Expiry: ${u.endDate}'),
                Text(currency.format(u.totalRentalFee),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: active
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SmartKeyScreen(
                                      bookingId: u.bookingId,
                                      unitCode: u.unitCode)),
                            )
                        : null,
                    icon: const Icon(Icons.vpn_key),
                    label: const Text('Smart Key'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            active ? AppColors.primary : Colors.grey.shade300,
                        foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => ContractOperationDialog(
                        bookingId: u.bookingId, onComplete: _refresh),
                  ),
                  child: const Text('Contract'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
