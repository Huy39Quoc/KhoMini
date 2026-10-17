import 'package:flutter/material.dart';
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
    appBar: AppBar(title: const Text('My waitlist')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _entries,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Could not load waitlist: ${snapshot.error}'));
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
                  title: Text('No waitlist entries'),
                  subtitle: Text('Join a waitlist from a facility when a unit type is full.'),
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
                    ? 'Book if still vacant. Notice expires: ${DateFormat('dd/MM/yyyy HH:mm').format(expiryLocal)}'
                    : status.replaceAll('_', ' ')),
                trailing: canLeave ? TextButton(
                  onPressed: () => _leave(entry['id'].toString()),
                  child: const Text('Leave'),
                ) : null,
              );
            },
          ),
        );
      },
    ),
  );
}
