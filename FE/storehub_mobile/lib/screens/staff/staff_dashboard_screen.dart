import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/facility_ops_api_service.dart';
import '../../widgets/state_views.dart';
import '../common/profile_screen.dart';

/// Flow 2 (Storage Check-in and Handover). Wires
/// FacilityOperationsController, merged onto the BE after this screen was
/// first built as an honest "not connected yet" placeholder.
class StaffDashboardScreen extends StatefulWidget {
  final UserModel user;
  const StaffDashboardScreen({super.key, required this.user});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final FacilityOpsApiService _opsService = FacilityOpsApiService();
  final _dateFmt = DateFormat('MMM d, yyyy');
  final _timeFmt = DateFormat('h:mm a');

  bool _isLoadingFacility = true;
  String? _facilityId;
  String? _facilityName;
  String? _facilityError;

  DateTime _selectedDate = DateTime.now();
  Future<List<dynamic>>? _scheduleFuture;

  @override
  void initState() {
    super.initState();
    _loadFacility();
  }

  Future<void> _loadFacility() async {
    setState(() {
      _isLoadingFacility = true;
      _facilityError = null;
    });
    try {
      final facility = await _opsService.getMyFacility();
      if (!mounted) return;
      final id = facility['id']?.toString();
      setState(() {
        _facilityId = id;
        _facilityName = facility['name']?.toString();
        _isLoadingFacility = false;
      });
      if (id != null && id.isNotEmpty) _loadSchedule();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _facilityError = e.toString().replaceAll('Exception: ', '');
        _isLoadingFacility = false;
      });
    }
  }

  void _loadSchedule() {
    if (_facilityId == null) return;
    setState(() {
      _scheduleFuture =
          _opsService.getDailySchedule(facilityId: _facilityId!, date: _selectedDate);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSchedule();
    }
  }

  bool _isCheckIn(String? scheduleType) {
    final t = (scheduleType ?? '').toUpperCase();
    return t.contains('IN');
  }

  Future<void> _openHandoverSheet(Map item, {required bool isCheckIn}) async {
    String unitCondition = 'Good / clean';
    String lockCondition = 'Locked & working';
    final notesController = TextEditingController();
    bool submitting = false;

    final bookingId = item['bookingId']?.toString() ?? '';
    final unitCode = item['unitCode']?.toString() ?? '';
    final customerName = item['customerName']?.toString() ?? 'Customer';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isCheckIn ? 'Check-in • Unit $unitCode' : 'Check-out • Unit $unitCode',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(customerName, style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 18),
                const Text('Unit condition', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: unitCondition,
                  items: const [
                    DropdownMenuItem(value: 'Good / clean', child: Text('Good / clean')),
                    DropdownMenuItem(value: 'Needs cleaning', child: Text('Needs cleaning')),
                    DropdownMenuItem(value: 'Damaged', child: Text('Damaged')),
                  ],
                  onChanged: (v) => setSheet(() => unitCondition = v ?? unitCondition),
                ),
                const SizedBox(height: 14),
                const Text('Lock condition', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: lockCondition,
                  items: const [
                    DropdownMenuItem(value: 'Locked & working', child: Text('Locked & working')),
                    DropdownMenuItem(value: 'Unlocked', child: Text('Unlocked')),
                    DropdownMenuItem(value: 'Damaged / needs repair', child: Text('Damaged / needs repair')),
                  ],
                  onChanged: (v) => setSheet(() => lockCondition = v ?? lockCondition),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setSheet(() => submitting = true);
                          try {
                            if (isCheckIn) {
                              await _opsService.checkIn(
                                bookingId: bookingId,
                                facilityId: _facilityId!,
                                unitCondition: unitCondition,
                                lockCondition: lockCondition,
                                notes: notesController.text,
                              );
                            } else {
                              await _opsService.checkOut(
                                bookingId: bookingId,
                                facilityId: _facilityId!,
                                unitCondition: unitCondition,
                                lockCondition: lockCondition,
                                notes: notesController.text,
                              );
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isCheckIn
                                    ? 'Check-in completed for $customerName'
                                    : 'Check-out completed for $customerName'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _loadSchedule();
                          } catch (e) {
                            setSheet(() => submitting = false);
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceAll('Exception: ', '')),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isCheckIn ? 'Complete Check-in' : 'Complete Check-out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Staff Operations'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                widget.user.fullName.isNotEmpty ? widget.user.fullName.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(user: widget.user)),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoadingFacility
          ? const AppLoadingState(message: 'Loading your facility...')
          : _facilityError != null
              ? AppErrorState(message: _facilityError!, onRetry: _loadFacility)
              : (_facilityId == null || _facilityId!.isEmpty)
                  ? const AppEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No facility assigned',
                      message: 'Ask an administrator to assign you to a facility to see your daily schedule.',
                    )
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: AppColors.primaryContainer,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_facilityName ?? 'Your facility',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(_dateFmt.format(_selectedDate),
                                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_drop_down, color: Colors.white),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async => _loadSchedule(),
                            child: FutureBuilder<List<dynamic>>(
                              future: _scheduleFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const AppLoadingState(message: 'Loading schedule...');
                                }
                                if (snapshot.hasError) {
                                  return AppErrorState(
                                    message: snapshot.error.toString().replaceAll('Exception: ', ''),
                                    onRetry: _loadSchedule,
                                  );
                                }
                                final items = snapshot.data ?? [];
                                if (items.isEmpty) {
                                  return const AppEmptyState(
                                    icon: Icons.event_available,
                                    title: 'Nothing scheduled',
                                    message: 'No check-ins or check-outs for this date.',
                                  );
                                }
                                return ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index] as Map;
                                    final isIn = _isCheckIn(item['scheduleType']?.toString());
                                    final time = item['scheduledTime'] != null
                                        ? DateTime.tryParse(item['scheduledTime'].toString())
                                        : null;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: CircleAvatar(
                                          backgroundColor: isIn
                                              ? AppColors.success.withValues(alpha: 0.15)
                                              : AppColors.secondaryContainer.withValues(alpha: 0.15),
                                          child: Icon(
                                            isIn ? Icons.login : Icons.logout,
                                            color: isIn ? AppColors.success : AppColors.secondaryContainer,
                                          ),
                                        ),
                                        title: Text(item['customerName']?.toString() ?? 'Customer',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        subtitle: Text(
                                          'Unit ${item['unitCode'] ?? '-'} • ${isIn ? 'Check-in' : 'Check-out'}'
                                          '${time != null ? ' • ${_timeFmt.format(time)}' : ''}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            minimumSize: const Size(0, 36),
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                          ),
                                          onPressed: () => _openHandoverSheet(item, isCheckIn: isIn),
                                          child: Text(isIn ? 'Check in' : 'Check out', style: const TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
