import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/facility_management_models.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/state_views.dart';

class StaffUnitsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const StaffUnitsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<StaffUnitsScreen> createState() => _StaffUnitsScreenState();
}

class _StaffUnitsScreenState extends State<StaffUnitsScreen> {
  final FacilityOpsApiService _service = FacilityOpsApiService();

  late Future<List<FacilityUnitModel>> _future;
  String? _busyUnitId;

  @override
  void initState() {
    super.initState();
    _future = _service.getFacilityUnits(widget.facilityId);
  }

  void _reload() {
    setState(() {
      _future = _service.getFacilityUnits(widget.facilityId);
    });
  }

  static const Color _reservedColor = Color(0xFF3B82F6);

  Color _color(String status) {
    switch (status) {
      case 'AVAILABLE':
        return AppColors.success;
      case 'OCCUPIED':
        return AppColors.error;
      case 'RESERVED':
        return _reservedColor;
      default:
        return AppColors.warning; // UNDER_MAINTENANCE: cần kiểm tra / bảo trì
    }
  }

  String _hint(String status) {
    switch (status) {
      case 'AVAILABLE':
        return 'Sẵn sàng cho thuê';
      case 'RESERVED':
        return 'Khách đã đặt, đang chờ nhận kho';
      case 'OCCUPIED':
        return 'Đang có khách thuê';
      case 'UNDER_MAINTENANCE':
        return 'Cần kiểm tra trước khi cho thuê lại';
      default:
        return '';
    }
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _legend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          _legendItem(AppColors.success, 'Trống'),
          _legendItem(_reservedColor, 'Đã giữ chỗ'),
          _legendItem(AppColors.error, 'Đang thuê'),
          _legendItem(AppColors.warning, 'Cần kiểm tra'),
        ],
      ),
    );
  }

  Future<void> _change(FacilityUnitModel unit, String target) async {
    setState(() => _busyUnitId = unit.id);
    try {
      await _service.updateUnitStatus(
        unitId: unit.id,
        facilityId: widget.facilityId,
        status: target,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            target == 'UNDER_MAINTENANCE'
                ? 'Đã đánh dấu ngăn ${unit.unitCode} cần kiểm tra'
                : 'Ngăn ${unit.unitCode} đã sẵn sàng cho thuê',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyUnitId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('Ngăn kho • ${widget.facilityName}')),
      body: FutureBuilder<List<FacilityUnitModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Đang tải ngăn kho...');
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message:
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _reload,
            );
          }

          final units = snapshot.data ?? <FacilityUnitModel>[];

          if (units.isEmpty) {
            return const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Chưa có ngăn kho',
              message: 'Cơ sở này chưa có ngăn kho.',
            );
          }

          return Column(
            children: [
              _legend(),
              Expanded(child: RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {
              }
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: units.length,
              itemBuilder: (context, index) {
                final unit = units[index];
                final color = _color(unit.status);
                final busy = _busyUnitId == unit.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(Icons.inventory_2,
                                  color: color, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ngăn ${unit.unitCode}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    [
                                      unit.unitType,
                                      if (unit.floorLevel.isNotEmpty)
                                        unit.floorLevel,
                                    ].join(' • '),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unit.statusLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: color),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hint(unit.status),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant),
                        ),
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          )
                        else if (unit.status == 'AVAILABLE')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _change(unit, 'UNDER_MAINTENANCE'),
                              icon: const Icon(Icons.build_outlined, size: 16),
                              label: const Text('Báo cần kiểm tra / bảo trì'),
                            ),
                          )
                        else if (unit.status == 'UNDER_MAINTENANCE')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ElevatedButton.icon(
                              onPressed: () => _change(unit, 'AVAILABLE'),
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 16),
                              label: const Text('Đã kiểm tra xong, cho thuê lại'),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ))],
          );
        },
      ),
    );
  }
}
