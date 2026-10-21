import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/booking_api_service.dart';
import 'payment_screen.dart';

/// The server is the source of truth: a booking may expire or be confirmed
/// while the app is closed. Do not persist payment URLs or booking snapshots.
class PendingBookingsSection extends StatefulWidget {
  const PendingBookingsSection({super.key});

  @override
  State<PendingBookingsSection> createState() => _PendingBookingsSectionState();
}

class _PendingBookingsSectionState extends State<PendingBookingsSection>
    with WidgetsBindingObserver {
  final _api = BookingApiService();
  late Future<List<Map<String, dynamic>>> _bookings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bookings = _api.getPayableBookings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _bookings = _api.getPayableBookings();
      });
    }
  }

  Future<void> _resume(Map<String, dynamic> booking) async {
    // Re-check the booking before opening payment; the list can be stale.
    try {
      final current = await _api.getPayableBookings();
      if (!mounted) return;
      final found = current.where((b) => b['id'] == booking['id']).toList();
      setState(() {
        _bookings = Future.value(current);
      });
      if (found.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đơn này không còn thanh toán được.')),
        );
        return;
      }
      final item = found.first;
      final startDate = DateTime.tryParse(item['startDate']?.toString() ?? '');
      final id = item['id']?.toString() ?? '';
      if (startDate == null || id.isEmpty) {
        throw const FormatException('Thông tin đơn chưa đầy đủ');
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            bookingId: id,
            bookingCode: item['bookingCode']?.toString() ?? '',
            facilityName: item['facilityName']?.toString() ?? '',
            unitTypeName: item['unitTypeName']?.toString() ?? '',
            unitTypeDimensions: item['unitTypeDimensions']?.toString() ?? '',
            startDate: startDate,
            rentalMonths: (item['rentalMonths'] as num?)?.toInt() ?? 0,
            totalRentalFee: (item['totalRentalFee'] as num?)?.toDouble() ?? 0,
            depositAmount: (item['depositAmount'] as num?)?.toDouble() ?? 0,
            totalExtraFees: (item['totalExtraFees'] as num?)?.toDouble() ?? 0,
            expiresAt: DateTime.tryParse(item['expiresAt']?.toString() ?? ''),
          ),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bookings,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Material(
            color: Colors.transparent,
            child: ListTile(
              title: const Text('Không tải được các đơn đang chờ'),
              trailing:
                  TextButton(onPressed: _reload, child: const Text('Thử lại')),
            ),
          );
        }
        final bookings = snapshot.data ?? [];
        if (bookings.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Đơn đang chờ thanh toán',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final booking in bookings)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _resume(booking),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.timer_outlined,
                            color: Color(0xFFD97706),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking['unitTypeName']?.toString() ??
                                    booking['bookingCode']?.toString() ??
                                    'Đặt kho',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${booking['facilityName'] ?? ''} • ${booking['bookingCode'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Thanh toán',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
