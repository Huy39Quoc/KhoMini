import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/unit_type_model.dart';

class FacilityDetailScreen extends StatefulWidget {
  const FacilityDetailScreen({super.key});

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  // Dữ liệu mẫu mô phỏng API trả về từ Spring Boot
  final List<UnitTypeModel> unitTypes = [
    UnitTypeModel(
      id: 1,
      typeName: 'Locker Nhỏ (S)',
      dimensions: '1.0m x 1.0m x 1.2m',
      areaSqMeters: 1.0,
      basePriceMonthly: 450000,
      depositAmount: 450000,
      hasClimateControl: false,
    ),
    UnitTypeModel(
      id: 2,
      typeName: 'Kho Tiêu Chuẩn (M)',
      dimensions: '1.5m x 2.0m x 2.5m',
      areaSqMeters: 3.0,
      basePriceMonthly: 1200000,
      depositAmount: 1200000,
      hasClimateControl: true,
    ),
    UnitTypeModel(
      id: 3,
      typeName: 'Kho Lớn (L)',
      dimensions: '2.5m x 3.0m x 3.0m',
      areaSqMeters: 7.5,
      basePriceMonthly: 2600000,
      depositAmount: 2600000,
      hasClimateControl: true,
    ),
  ];

  int selectedUnitIndex = 1;
  int rentalMonths = 1;
  DateTime startDate = DateTime.now().add(const Duration(days: 1));
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  Widget build(BuildContext context) {
    final selectedUnit = unitTypes[selectedUnitIndex];
    final totalRent = selectedUnit.basePriceMonthly * rentalMonths;
    final totalInitialPayment = totalRent + selectedUnit.depositAmount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chi tiết Cơ sở & Đặt chỗ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Facility Hero Card
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KhoMini - Chi nhánh Tân Bình',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(
                        Icons.location_on,
                        color: AppColors.accent,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '123 Cộng Hòa, Phường 13, Quận Tân Bình, TP. HCM',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFeatureChip(Icons.lock_clock, 'Truy cập 24/7'),
                      _buildFeatureChip(Icons.ac_unit, 'Máy lạnh kiểm soát ẩm'),
                      _buildFeatureChip(Icons.videocam, 'CCTV 360°'),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Chọn loại kho
                  const Text(
                    '1. Chọn loại không gian lưu trữ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: unitTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = unitTypes[index];
                      final isSelected = selectedUnitIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() => selectedUnitIndex = index),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.border,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.typeName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Kích thước: ${item.dimensions} (${item.areaSqMeters}m²)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${currencyFormat.format(item.basePriceMonthly)}/th',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 2. Thời gian thuê
                  const Text(
                    '2. Thời gian bắt đầu & Thời hạn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Ngày bắt đầu nhận kho:',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 60),
                                  ),
                                );
                                if (picked != null)
                                  setState(() => startDate = picked);
                              },
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                DateFormat('dd/MM/yyyy').format(startDate),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Thời hạn thuê:',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            DropdownButton<int>(
                              value: rentalMonths,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text('1 Tháng'),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text('3 Tháng (Ưu đãi 5%)'),
                                ),
                                DropdownMenuItem(
                                  value: 6,
                                  child: Text('6 Tháng (Ưu đãi 10%)'),
                                ),
                                DropdownMenuItem(
                                  value: 12,
                                  child: Text('12 Tháng (Ưu đãi 15%)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => rentalMonths = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Chi tiết chi phí
                  const Text(
                    '3. Bảng kê thanh toán',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildFeeRow(
                          'Phí thuê ($rentalMonths tháng)',
                          currencyFormat.format(totalRent),
                        ),
                        const SizedBox(height: 8),
                        _buildFeeRow(
                          'Tiền cọc bảo đảm (Hoàn lại)',
                          currencyFormat.format(selectedUnit.depositAmount),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(),
                        ),
                        _buildFeeRow(
                          'Tổng thanh toán ban đầu',
                          currencyFormat.format(totalInitialPayment),
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 80,
                  ), // Chừa khoảng trống cho Bottom Bar
                ],
              ),
            ),
          ],
        ),
      ),

      // Sticky Bottom Action
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng thanh toán',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      currencyFormat.format(totalInitialPayment),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  // Gửi request POST sang API /api/bookings của Spring Boot
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Tạo yêu cầu đặt kho ${selectedUnit.typeName} thành công!',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Đặt kho & Thanh toán cọc',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String title, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
