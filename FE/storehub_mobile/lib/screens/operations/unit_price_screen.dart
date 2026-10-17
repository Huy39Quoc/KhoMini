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
    final rawPrice = _num(unitType['basePricePerMonth']);
    final rawDeposit = _num(unitType['depositAmount']);

    final result = await showDialog<_PriceEditResult>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _EditPriceDialog(
        title: 'Chỉnh sửa giá - ${unitType['typeName'] ?? 'Loại kho'}',
        initialPrice: rawPrice,
        initialDeposit: rawDeposit,
      ),
    );

    if (result == null || !mounted) return;

    try {
      await _admin.updateUnitTypePrice(
        unitTypeId: unitType['id'].toString(),
        basePricePerMonth: result.price,
        depositAmount: result.deposit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật giá thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cập nhật thất bại: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Giá loại kho')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Đang tải loại kho...');
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
              title: 'Chưa có loại kho',
              message: 'Chưa có loại kho nào.',
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
                      'Thuê ${_currency.format(_num(item['basePricePerMonth']))}/tháng'
                      ' • Cọc ${_currency.format(_num(item['depositAmount']))}',
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

class _PriceEditResult {
  final double price;
  final double deposit;
  const _PriceEditResult({required this.price, required this.deposit});
}

class _EditPriceDialog extends StatefulWidget {
  final String title;
  final double initialPrice;
  final double initialDeposit;

  const _EditPriceDialog({
    required this.title,
    required this.initialPrice,
    required this.initialDeposit,
  });

  @override
  State<_EditPriceDialog> createState() => _EditPriceDialogState();
}

class _EditPriceDialogState extends State<_EditPriceDialog> {
  late final TextEditingController _priceController;
  late final TextEditingController _depositController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.initialPrice.round().toString(),
    );
    _depositController = TextEditingController(
      text: widget.initialDeposit.round().toString(),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  double? _parseAmount(String? value) {
    if (value == null) return null;
    var cleaned = value.trim().replaceAll(',', '').replaceAll(' ', '');
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(cleaned)) {
      cleaned = cleaned.replaceAll('.', '');
    }
    return double.tryParse(cleaned);
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final price = _parseAmount(_priceController.text);
      final deposit = _parseAmount(_depositController.text);
      if (price != null && deposit != null) {
        Navigator.pop(
          context,
          _PriceEditResult(price: price, deposit: deposit),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá thuê tháng (₫)',
                hintText: 'Ví dụ: 1200000',
              ),
              validator: (value) {
                final parsed = _parseAmount(value);
                if (parsed == null || parsed <= 0) {
                  return 'Vui lòng nhập giá lớn hơn 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _depositController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tiền cọc (₫)',
                hintText: 'Ví dụ: 1200000',
              ),
              validator: (value) {
                final parsed = _parseAmount(value);
                if (parsed == null || parsed < 0) {
                  return 'Vui lòng nhập tiền cọc từ 0 trở lên';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

