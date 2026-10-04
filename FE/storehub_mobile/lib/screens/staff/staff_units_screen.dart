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

  Color _color(String status) {
    switch (status) {
      case 'AVAILABLE':
        return AppColors.success;
      case 'OCCUPIED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
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
                ? 'Unit ${unit.unitCode} marked for inspection'
                : 'Unit ${unit.unitCode} is available again',
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
      appBar: AppBar(title: Text('Units • ${widget.facilityName}')),
      body: FutureBuilder<List<FacilityUnitModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(message: 'Loading units...');
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
              title: 'No storage units',
              message: 'This facility has no storage units yet.',
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: units.length,
              itemBuilder: (context, index) {
                final unit = units[index];
                final color = _color(unit.status);
                final busy = _busyUnitId == unit.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Icon(Icons.inventory_2, color: color, size: 18),
                    ),
                    title: Text(
                      'Unit ${unit.unitCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      [
                        unit.unitType,
                        if (unit.floorLevel.isNotEmpty) unit.floorLevel,
                        unit.statusLabel,
                      ].join(' • '),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : unit.status == 'AVAILABLE'
                            ? TextButton(
                                onPressed: () =>
                                    _change(unit, 'UNDER_MAINTENANCE'),
                                child: const Text('Needs inspection'),
                              )
                            : unit.status == 'UNDER_MAINTENANCE'
                                ? TextButton(
                                    onPressed: () =>
                                        _change(unit, 'AVAILABLE'),
                                    child: const Text('Mark available'),
                                  )
                                : null,
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
