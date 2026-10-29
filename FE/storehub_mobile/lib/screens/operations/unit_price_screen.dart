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
                      ' • Cọc niêm yết: ${_currency.format(_num(item['depositAmount']))}',
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
  final NumberFormat _currency =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

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

  String _formatPreview(String text) {
    final val = _parseAmount(text);
    if (val == null || val < 0) return '';
    return _currency.format(val);
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
    final pricePreview = _formatPreview(_priceController.text);
    final depositPreview = _formatPreview(_depositController.text);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.price_change_outlined,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Informational note
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Phân định logic doanh thu & bảo đảm:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Giá thuê: Khoản thu theo tháng (ghi nhận Doanh thu).\n'
                        '• Tiền cọc: Khoản ký quỹ bảo đảm kho (Hoàn lại 100% khi trả kho).\n'
                        '💡 Lưu ý: Khi cơ sở áp dụng Chính sách % cọc (ví dụ 20%), tiền cọc khách trả sẽ tính theo % của chi nhánh đó. Nếu chi nhánh không dùng %, hệ thống sẽ dùng số tiền cọc niêm yết ở đây.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Field 1: Giá thuê tháng
                const Text(
                  'Giá thuê tháng',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.sell_outlined, size: 18),
                    suffixText: '₫/tháng',
                    hintText: 'Nhập giá thuê',
                    helperText: pricePreview.isNotEmpty ? '= $pricePreview / tháng' : null,
                    helperStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    final parsed = _parseAmount(value);
                    if (parsed == null || parsed <= 0) {
                      return 'Vui lòng nhập giá lớn hơn 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Field 2: Tiền cọc
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tiền cọc bảo đảm',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _depositController.text = _priceController.text;
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.sync_alt, size: 12, color: AppColors.primary),
                            SizedBox(width: 3),
                            Text(
                              'Cọc = 1 tháng thuê',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _depositController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.shield_outlined, size: 18),
                    suffixText: '₫ cọc',
                    hintText: 'Nhập tiền cọc',
                    helperText: depositPreview.isNotEmpty ? '= $depositPreview (Ký quỹ hoàn lại)' : null,
                    helperStyle: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    final parsed = _parseAmount(value);
                    if (parsed == null || parsed < 0) {
                      return 'Vui lòng nhập tiền cọc từ 0 trở lên';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Lưu thay đổi'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

