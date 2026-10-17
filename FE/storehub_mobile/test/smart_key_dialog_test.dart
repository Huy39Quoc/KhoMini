import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/screens/customer/my_units/smart_key_screen.dart';
import 'package:storehub_mobile/services/storage_api_service.dart';

class _WrongPasswordStorageService extends StorageApiService {
  @override
  Future<Map<String, dynamic>> getSmartAccess(String bookingId) async => {
        'bookingId': bookingId,
        'unitCode': 'M-201',
        'pinSet': true,
        'locked': true,
        'attemptsRemaining': 5,
      };

  @override
  Future<Map<String, dynamic>> resetPin(String bookingId, String password,
      {String? newPin}) async {
    throw Exception('Mật khẩu không đúng');
  }
}

void main() {
  testWidgets('Wrong password in reset PIN closes dialog and shows an error',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SmartKeyScreen(
        bookingId: 'booking-1',
        unitNumber: 'M-201',
        apiService: _WrongPasswordStorageService(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Quên mã PIN?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quên mã PIN?'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu tài khoản'), 'wrong');
    await tester.tap(find.text('Đặt lại PIN'));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu không đúng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
