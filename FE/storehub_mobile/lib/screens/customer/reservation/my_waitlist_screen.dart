import 'package:flutter/material.dart';
import '../../../core/utils/vi_labels.dart';
import 'package:intl/intl.dart';
import '../../../services/booking_api_service.dart';

class MyWaitlistScreen extends StatefulWidget {
  const MyWaitlistScreen({super.key});

  @override
  State<MyWaitlistScreen> createState() => _MyWaitlistScreenState();
}

class _MyWaitlistScreenState extends State<MyWaitlistScreen> {
  final BookingApiService _api = BookingApiService();
  late Future<List<Map<String, dynamic>>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _api.getMyWaitlist();
  }

  Future<void> _refresh() async {
    setState(() => _entries = _api.getMyWaitlist());
    try { await _entries; } catch (_) { /* FutureBuilder shows the error. */ }
  }

  Future<void> _leave(String id) async {
    try {
      await _api.leaveWaitlist(id);
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Danh sách chờ của tôi')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _entries,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Không tải được danh sách chờ: ${snapshot.error}'));
        }
        final entries = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: entries.isEmpty ? 1 : entries.length,
            itemBuilder: (context, index) {
              if (entries.isEmpty) {
                return const ListTile(
                  title: Text('Chưa có trong danh sách chờ'),
                  subtitle: Text('Vào danh sách chờ tại cơ sở khi loại kho bạn cần đã hết chỗ.'),
                );
              }
              final entry = entries[index];
              final status = entry['status']?.toString() ?? 'WAITING';
              final canLeave = status == 'WAITING' || status == 'NOTIFIED';
              final expiry = entry['offerExpiresAt']?.toString();
              final expiryLocal = expiry == null ? null : DateTime.tryParse(expiry)?.toLocal();
              return ListTile(
                title: Text('${entry['facilityName']} • ${entry['unitTypeName']}'),
                subtitle: Text(status == 'NOTIFIED' && expiryLocal != null
                    ? 'Hãy đặt ngay nếu còn trống. Thông báo hết hạn lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(expiryLocal)}'
                    : ViLabels.waitlist(status)),
                trailing: canLeave ? TextButton(
                  onPressed: () => _leave(entry['id'].toString()),
                  child: const Text('Rời đi'),
                ) : null,
              );
            },
          ),
        );
      },
    ),
  );
}
