import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/facility_management_models.dart';
import '../../models/facility_operations_models.dart';
import '../../services/facility_ops_api_service.dart';

class AppointmentAssignmentScreen extends StatefulWidget {
  final String facilityId;

  const AppointmentAssignmentScreen({super.key, required this.facilityId});

  @override
  State<AppointmentAssignmentScreen> createState() =>
      _AppointmentAssignmentScreenState();
}

class _AppointmentAssignmentScreenState
    extends State<AppointmentAssignmentScreen> {
  final _api = FacilityOpsApiService();
  DateTime _date = DateTime.now();
  late Future<List<DailyScheduleModel>> _schedule;
  late Future<List<FacilityStaffModel>> _staff;
  String? _updating;

  @override
  void initState() {
    super.initState();
    _staff = _api.getFacilityStaff(widget.facilityId);
    _reload();
  }

  void _reload() {
    setState(() {
      _schedule = _api.getDailySchedule(
        facilityId: widget.facilityId,
        date: _date,
      );
    });
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null || !mounted) return;
    _date = selected;
    _reload();
  }

  Future<void> _assign(DailyScheduleModel item, String? staffId) async {
    setState(() => _updating = item.bookingId);
    try {
      await _api.assignAppointment(
        facilityId: widget.facilityId,
        appointment: item,
        staffId: staffId,
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Handover appointments')),
      body: Column(
        children: [
          ListTile(
            title: Text(DateFormat('dd/MM/yyyy').format(_date)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _chooseDate,
          ),
          Expanded(
            child: FutureBuilder<List<FacilityStaffModel>>(
              future: _staff,
              builder: (context, staffSnapshot) {
                if (staffSnapshot.hasError) {
                  return Center(child: Text('Staff: ${staffSnapshot.error}'));
                }
                if (!staffSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return FutureBuilder<List<DailyScheduleModel>>(
                  future: _schedule,
                  builder: (context, scheduleSnapshot) {
                    if (scheduleSnapshot.hasError) {
                      return Center(child: Text('${scheduleSnapshot.error}'));
                    }
                    if (!scheduleSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final appointments = scheduleSnapshot.data!;
                    if (appointments.isEmpty) {
                      return const Center(child: Text('No appointments for this date.'));
                    }
                    final staff = staffSnapshot.data!;
                    return RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _schedule;
                      },
                      child: ListView.builder(
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final item = appointments[index];
                          final chosen = staff.any((s) => s.id == item.assignedStaffId)
                              ? item.assignedStaffId
                              : null;
                          return Card(
                            margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item.bookingCode} • ${item.unitCode}',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${item.isCheckIn ? 'Check-in' : 'Check-out'} • '
                                      '${item.customerName} • '
                                      '${item.scheduledTime == null ? '-' : DateFormat('HH:mm').format(item.scheduledTime!)}'),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('${item.bookingId}-${item.scheduleType}-${chosen ?? ''}'),
                                    initialValue: chosen ?? '',
                                    decoration: const InputDecoration(labelText: 'Assigned staff'),
                                    items: [
                                      const DropdownMenuItem(value: '', child: Text('Unassigned')),
                                      ...staff.map((s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Text(s.fullName),
                                          )),
                                    ],
                                    onChanged: _updating == item.bookingId
                                        ? null
                                        : (id) => _assign(item, id == '' ? null : id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
