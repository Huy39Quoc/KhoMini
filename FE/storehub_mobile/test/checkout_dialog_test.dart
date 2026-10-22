import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/models/my_unit_model.dart';
import 'package:storehub_mobile/screens/customer/my_units/contract_operation_dialog.dart';

void main() {
  testWidgets(
      'Checkout dialog has optional bank account info and expands when checked',
      (WidgetTester tester) async {
    final unit = MyUnitModel(
      bookingId: 'b-1',
      bookingCode: 'BK001',
      unitCode: 'S-101',
      facilityName: 'StoreHub D1',
      facilityAddress: '123 Nguyen Hue',
      typeName: 'Small',
      status: 'ACTIVE',
      totalRentalFee: 500000,
      openTime: '08:00',
      closeTime: '20:00',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContractOperationDialog(
            unit: unit,
            isExtension: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and return appointment section
    expect(find.text('Yêu cầu trả kho'), findsOneWidget);
    expect(find.text('2. Tài khoản nhận hoàn cọc (Tùy chọn)'), findsOneWidget);
    expect(
      find.text('Nhận hoàn cọc qua chuyển khoản ngân hàng'),
      findsOneWidget,
    );
    expect(
      find.text(
          'Không bắt buộc nhập lúc này. Bạn có thể đối soát và nhận hoàn cọc trực tiếp tại cơ sở với nhân viên sau khi nghiệm thu.'),
      findsOneWidget,
    );

    // Bank fields shouldn't be visible yet
    expect(find.text('Số tài khoản'), findsNothing);

    // Tap checkbox to enable bank input
    await tester.tap(find.text('Nhận hoàn cọc qua chuyển khoản ngân hàng'));
    await tester.pumpAndSettle();

    // Bank fields should now be visible
    expect(find.text('Số tài khoản'), findsOneWidget);
    expect(find.text('Tên chủ tài khoản'), findsOneWidget);

    // Tap 'Xác nhận trả kho' without filling bank details
    await tester.tap(find.text('Xác nhận trả kho'));
    await tester.pumpAndSettle();

    // Error should be displayed preventing submission
    expect(
      find.text('Vui lòng nhập đầy đủ thông tin tài khoản nhận hoàn cọc.'),
      findsOneWidget,
    );
  });

  test('MyUnitModel with scheduled return is distinguished from active without appointment', () {
    final activeUnit = MyUnitModel(
      bookingId: 'b-1',
      bookingCode: 'BK001',
      unitCode: 'S-101',
      facilityName: 'StoreHub D1',
      facilityAddress: '123 Nguyen Hue',
      typeName: 'Small',
      status: 'ACTIVE',
      totalRentalFee: 500000,
    );
    final returnScheduledUnit = MyUnitModel(
      bookingId: 'b-2',
      bookingCode: 'BK002',
      unitCode: 'S-102',
      facilityName: 'StoreHub D1',
      facilityAddress: '123 Nguyen Hue',
      typeName: 'Small',
      status: 'ACTIVE',
      totalRentalFee: 500000,
      scheduledReturnTime: DateTime.now().add(const Duration(days: 1)),
    );

    expect(activeUnit.isActive, isTrue);
    expect(activeUnit.scheduledReturnTime, isNull);

    expect(returnScheduledUnit.isActive, isTrue);
    expect(returnScheduledUnit.scheduledReturnTime, isNotNull);
  });
}

