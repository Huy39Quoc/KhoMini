import 'package:flutter/material.dart';

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
          const SnackBar(content: Text('This booking is no longer payable.')),
        );
        return;
      }
      final item = found.first;
      final startDate = DateTime.tryParse(item['startDate']?.toString() ?? '');
      final id = item['id']?.toString() ?? '';
      if (startDate == null || id.isEmpty) {
        throw const FormatException('Incomplete booking details');
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
          return ListTile(
            title: const Text('Could not load pending bookings'),
            trailing: TextButton(onPressed: _reload, child: const Text('Retry')),
          );
        }
        final bookings = snapshot.data ?? [];
        if (bookings.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pending reservations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            for (final booking in bookings)
              Card(
                child: ListTile(
                  title: Text(booking['unitTypeName']?.toString() ??
                      booking['bookingCode']?.toString() ?? 'Reservation'),
                  subtitle: Text(
                    '${booking['facilityName'] ?? ''} • ${booking['bookingCode'] ?? ''}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _resume(booking),
                ),
              ),
          ],
        );
      },
    );
  }
}
