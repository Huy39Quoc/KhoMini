import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/facility_management_models.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/state_views.dart';

class BookingAssignmentScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const BookingAssignmentScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<BookingAssignmentScreen> createState() =>
      _BookingAssignmentScreenState();
}

class _BookingAssignmentScreenState extends State<BookingAssignmentScreen> {
  final FacilityOpsApiService _opsService = FacilityOpsApiService();

  Future<List<FacilityBookingModel>>? _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    setState(() {
      _bookingsFuture = _opsService.getConfirmedBookings(
        widget.facilityId,
      );
    });
  }

  Future<void> _refreshBookings() async {
    _loadBookings();

    try {
      await _bookingsFuture;
    } catch (_) {
    }
  }

  Future<void> _openUnitSelector(
    FacilityBookingModel booking,
  ) async {
    List<FacilityUnitModel> units;

    try {
      units = await _opsService.getFacilityUnits(
        widget.facilityId,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_errorMessage(error));
      return;
    }

    final availableUnits = units.where((unit) {
      return unit.isAvailable && unit.unitTypeId == booking.unitTypeId;
    }).toList();

    if (availableUnits.isEmpty) {
      if (!mounted) {
        return;
      }

      _showError(
        'No available ${booking.unitType} units found.',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose replacement unit',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${booking.bookingCode} • ${booking.unitType}',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableUnits.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final unit = availableUnits[index];

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                        title: Text('Unit ${unit.unitCode}'),
                        subtitle: Text(
                          unit.floorLevel.isEmpty
                              ? unit.unitType
                              : '${unit.unitType} • ${unit.floorLevel}',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                        ),
                        onTap: () async {
                          try {
                            await _opsService.assignUnitToBooking(
                              widget.facilityId,
                              booking.id,
                              unit.id,
                            );

                            if (!sheetContext.mounted) {
                              return;
                            }

                            Navigator.pop(sheetContext);

                            if (!mounted) {
                              return;
                            }

                            _showSuccess(
                              'Booking moved to ${unit.unitCode}.',
                            );
                            _loadBookings();
                          } catch (error) {
                            if (!sheetContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _errorMessage(error),
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Confirmed Bookings'),
      ),
      body: FutureBuilder<List<FacilityBookingModel>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Loading confirmed bookings...',
            );
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: _errorMessage(snapshot.error!),
              onRetry: _loadBookings,
            );
          }

          final bookings = snapshot.data ?? <FacilityBookingModel>[];

          if (bookings.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshBookings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  AppEmptyState(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'No confirmed bookings',
                    message: 'Confirmed bookings will appear here.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshBookings,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final booking = bookings[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                booking.bookingCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Text(
                              'CONFIRMED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(booking.customerName),
                        Text(
                          booking.customerEmail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Current unit: ${booking.unitCode} '
                          '(${booking.unitType})',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${booking.startDate} → ${booking.endDate}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _openUnitSelector(booking);
                            },
                            icon: const Icon(
                              Icons.swap_horiz,
                            ),
                            label: const Text('Change Unit'),
                          ),
                        ),
                      ],
                    ),
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
