import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/models/facility_management_models.dart';
import 'package:storehub_mobile/models/my_unit_model.dart';
import 'package:storehub_mobile/screens/manager/handover_issue_resolution_dialog.dart';

void main() {
  const booking = FacilityBookingModel(
    id: 'booking',
    bookingCode: 'BK-ISSUE',
    customerName: 'Khách',
    customerEmail: 'customer@test.com',
    startDate: '2026-01-01',
    endDate: '2026-02-01',
    storageUnitId: 'broken',
    unitCode: 'A01',
    unitTypeId: 'small',
    unitType: 'Nhỏ',
    status: 'CONFIRMED',
    unitAssignmentConfirmed: false,
    handoverIssueStatus: 'OPEN',
    handoverIssueReason: 'Khóa hỏng',
  );

  testWidgets(
      'Manager cannot arrange a replacement without recording customer consent',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: HandoverIssueResolutionDialog(booking: booking, units: []))));
    await tester.tap(find.text('Xác nhận phương án'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nhập lý do;'), findsOneWidget);
    expect(find.text('Xử lý lỗi bàn giao của cơ sở'), findsOneWidget);
  });

  testWidgets(
      'Facility cancellation clearly requests a full refund and requires notes',
      (tester) async {
    Map<String, dynamic>? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () async {
                        result = await showDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (_) => const HandoverIssueResolutionDialog(
                                booking: booking, units: []));
                      },
                      child: const Text('Mở'),
                    )))));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy do lỗi cơ sở, hoàn toàn bộ').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Không áp phí hủy của khách'), findsOneWidget);
    await tester.enterText(find.byType(TextField),
        'Không còn ngăn sẵn sàng, đã trao đổi với khách');
    await tester.tap(find.text('Xác nhận phương án'));
    await tester.pumpAndSettle();
    expect(result?['action'], 'CANCEL_REFUND');
    expect(result?.containsKey('customerAgreed'), isFalse);
  });

  test(
      'Customer model preserves the facility failure flag for full-refund cancellation',
      () {
    final unit = MyUnitModel.fromJson({
      'bookingId': 'b',
      'handoverIssueStatus': 'OPEN',
      'handoverIssueReason': 'Khóa hỏng',
      'handoverIssueDueAt': '2026-11-01T09:00:00'
    });
    expect(unit.hasHandoverIssue, isTrue);
    expect(unit.handoverIssueReason, 'Khóa hỏng');
  });
}
