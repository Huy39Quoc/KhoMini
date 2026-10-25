import 'package:flutter/material.dart';
import '../../models/facility_management_models.dart';

class HandoverIssueResolutionDialog extends StatefulWidget {
  final FacilityBookingModel booking;
  final List<FacilityUnitModel> units;
  const HandoverIssueResolutionDialog(
      {super.key, required this.booking, required this.units});

  @override
  State<HandoverIssueResolutionDialog> createState() =>
      _HandoverIssueResolutionDialogState();
}

class _HandoverIssueResolutionDialogState
    extends State<HandoverIssueResolutionDialog> {
  final _notes = TextEditingController();
  String _action = 'REPLACE_UNIT';
  String? _unit;
  late DateTime _day;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _agreed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final original = DateTime.tryParse(widget.booking.startDate);
    _day = original != null && original.isAfter(tomorrow) ? original : tomorrow;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final cancelling = _action == 'CANCEL_REFUND';
    final appointment =
        DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);
    if (_notes.text.trim().isEmpty ||
        (!cancelling && !_agreed) ||
        (!cancelling && !appointment.isAfter(DateTime.now())) ||
        (_action == 'REPLACE_UNIT' && _unit == null)) {
      setState(() => _error =
          'Nhập lý do; chọn ngăn/giờ hợp lệ và xác nhận khách đã đồng ý nếu đổi ngăn hoặc đổi lịch.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'action': _action,
      'notes': _notes.text.trim(),
      if (!cancelling) ...{
        'customerAgreed': _agreed,
        'scheduledCheckInTime': appointment.toIso8601String(),
      },
      if (_action == 'REPLACE_UNIT') 'replacementUnitId': _unit,
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.units
        .where((u) =>
            u.isAvailable &&
            u.unitTypeId == widget.booking.unitTypeId &&
            u.id != widget.booking.storageUnitId)
        .toList();
    return AlertDialog(
      title: const Text('Xử lý lỗi bàn giao của cơ sở'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.booking.handoverIssueReason),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _action,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Phương án'),
                  items: const [
                    DropdownMenuItem(
                        value: 'REPLACE_UNIT',
                        child: Text('Đổi ngăn cùng loại')),
                    DropdownMenuItem(
                        value: 'RESCHEDULE',
                        child: Text('Đổi lịch chờ sửa ngăn hiện tại')),
                    DropdownMenuItem(
                        value: 'CANCEL_REFUND',
                        child: Text('Hủy do lỗi cơ sở, hoàn toàn bộ')),
                  ],
                  onChanged: (v) => setState(() {
                    _action = v!;
                    _agreed = false;
                    _error = null;
                  }),
                ),
                if (_action == 'REPLACE_UNIT') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _unit,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Ngăn thay thế đang trống'),
                    items: options
                        .map((u) => DropdownMenuItem(
                            value: u.id, child: Text(u.unitCode)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _unit = v;
                      _agreed = false;
                    }),
                  ),
                  if (options.isEmpty)
                    const Text(
                        'Chưa có ngăn cùng loại đang trống. Có thể xử lý hủy và hoàn toàn bộ.'),
                ],
                if (_action != 'CANCEL_REFUND') ...[
                  const SizedBox(height: 12),
                  const Text(
                      'Thống nhất lịch mới với khách trước khi xác nhận. Kỳ thuê được tính lại đủ số tháng đã thanh toán, không thu thêm tiền.'),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text('${_day.day}/${_day.month}/${_day.year}'),
                    onPressed: () async {
                      final now = DateTime.now();
                      final selected = await showDatePicker(
                          context: context,
                          initialDate: _day,
                          firstDate: DateTime(now.year, now.month, now.day),
                          lastDate: now.add(const Duration(days: 365)));
                      if (selected != null && mounted) {
                        setState(() {
                          _day = selected;
                          _agreed = false;
                        });
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(_time.format(context)),
                    onPressed: () async {
                      final selected = await showTimePicker(
                          context: context, initialTime: _time);
                      if (selected != null && mounted) {
                        setState(() {
                          _time = selected;
                          _agreed = false;
                        });
                      }
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                        'Tôi đã liên hệ và khách đồng ý ngăn/lịch mới'),
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text(
                      'Hủy đơn và tạo yêu cầu hoàn toàn bộ cọc, tiền thuê và phí quản lý đã thu. Không áp phí hủy của khách; khoản hoàn vẫn cần đối soát trước khi hoàn tất.'),
                ],
                TextField(
                    controller: _notes,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Lý do / nội dung đã trao đổi với khách *')),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        FilledButton(
            onPressed: _submit, child: const Text('Xác nhận phương án')),
      ],
    );
  }
}
