import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/storage_api_service.dart';
import '../../../../models/my_unit_model.dart';
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
    _loadUnits();
  }

  void _loadUnits() {
    setState(() {
      // Directly map and cast the response list to List<MyUnitModel>
      _unitsFuture = _storageService.getMyRentedUnits().then((response) {
        return response.map((item) {
          if (item is MyUnitModel) return item;
          return MyUnitModel.fromJson(item as Map<String, dynamic>);
        }).toList();
      });
    });
  }

  // Trước đây bấm vào 1 unit không làm gì (onTap rỗng), khiến các tính
  // năng Smart Access / Gia hạn / Trả kho không thể truy cập từ đâu cả.
  void _showUnitActions(MyUnitModel unit) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.key, color: Colors.indigo),
              title: const Text('Smart Access (PIN / QR)'),
              enabled: unit.hasActiveAccess,
              subtitle: unit.hasActiveAccess
                  ? null
                  : const Text('Not available for this unit'),
              onTap: unit.hasActiveAccess
                  ? () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SmartKeyScreen(
                            bookingId: unit.bookingId,
                            unitNumber: unit.unitCode,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.update, color: Colors.indigo),
              title: const Text('Extend Rental'),
              onTap: () {
                Navigator.pop(ctx);
                _openContractOperation(unit, isExtension: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Request Checkout'),
              onTap: () {
                Navigator.pop(ctx);
                _openContractOperation(unit, isExtension: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openContractOperation(
    MyUnitModel unit, {
    required bool isExtension,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ContractOperationDialog(
        bookingId: unit.bookingId,
        isExtension: isExtension,
      ),
    );
    if (result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isExtension
                ? 'Rental extended successfully!'
                : 'Checkout requested successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadUnits();
    }
  }

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rented Units'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUnits,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: FutureBuilder<List<MyUnitModel>>(
        future: _unitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error loading units: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No rented storage units found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final units = snapshot.data!;
          return ListView.builder(
            itemCount: units.length,
            itemBuilder: (context, index) {
              final unit = units[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                child: ListTile(
                  title: Text('Unit: ${unit.unitCode}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Facility: ${unit.facilityName}\nStatus: ${unit.status}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showUnitActions(unit),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
