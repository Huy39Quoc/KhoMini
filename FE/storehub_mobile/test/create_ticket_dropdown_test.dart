import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/screens/customer/tickets/create_ticket_screen.dart';

void main() {
  testWidgets('CreateTicketScreen with preselected booking does not crash DropdownButton',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CreateTicketScreen(
          preselectedBookingId: '6ae0edb1-49d6-486d-b480-9d28546e23e9',
          preselectedUnitLabel: 'Ngăn S-101 • StoreHub District 1',
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify title and form rendered without any assertion error
    expect(find.text('Báo sự cố'), findsOneWidget);
    expect(find.text('Ngăn kho liên quan'), findsOneWidget);
    expect(find.text('Loại sự cố'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
