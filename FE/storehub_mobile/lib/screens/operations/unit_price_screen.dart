import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../services/catalog_api_service.dart';
import '../../services/facility_admin_api_service.dart';
import '../../widgets/state_views.dart';

class UnitPriceScreen extends StatefulWidget {
  const UnitPriceScreen({super.key});

  @override
  State<UnitPriceScreen> createState() => _UnitPriceScreenState();
}

class _UnitPriceScreenState extends State<UnitPriceScreen> {
  final CatalogApiService _catalog = CatalogApiService();
  final FacilityAdminApiService _admin = FacilityAdminApiService();
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _catalog.getUnitTypes();
  }

  void _reload() {
    setState(() {
      _future = _catalog.getUnitTypes();
    });
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _edit(Map<String, dynamic> unitType) async {
    final priceController = TextEditingController(
      text: _num(unitType['basePricePerMonth']).toStringAsFixed(2),
    );
    final depositController = TextEditingController(
      text: _num(unitType['depositAmount']).toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(unitType['typeName']?.toString() ?? 'Unit type'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monthly rent (\$)',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter an amount greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: depositController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Deposit amount (\$)',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed < 0) {
                      return 'Enter 0 or more';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final price = double.tryParse(priceController.text);
    final deposit = double.tryParse(depositController.text);
    priceController.dispose();
    depositController.dispose();

    if (confirmed != true || price == null || deposit == null) return;

    try {
      await _admin.updateUnitTypePrice(
        unitTypeId: unitType['id'].toString(),
        basePricePerMonth: price,
        depositAmount: deposit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price updated'),
          backgroundColor: AppColors.success,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Unit Prices')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Loading unit types...');
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message:
                  snapshot.error.toString().replaceAll('Exception: ', ''),
              onRetry: _reload,
            );
          }

          final items = (snapshot.data ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.price_change_outlined,
              title: 'No unit types',
              message: 'No unit types are defined yet.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {
              }
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => _edit(item),
                    title: Text(
                      item['typeName']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${item['dimensions'] ?? ''}\n'
                      'Rent ${_currency.format(_num(item['basePricePerMonth']))}/month'
                      ' • Deposit ${_currency.format(_num(item['depositAmount']))}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
