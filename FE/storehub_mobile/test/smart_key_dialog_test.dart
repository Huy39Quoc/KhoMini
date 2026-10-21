import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/screens/customer/my_units/smart_key_screen.dart';
import 'package:storehub_mobile/services/storage_api_service.dart';

class _MockStorageService extends StorageApiService {
  String? lastUpdatedCurrentPin;
  String? lastUpdatedNewPin;
  String? lastResetPassword;
  String? lastResetNewPin;
  bool pinSet = true;

  @override
  Future<Map<String, dynamic>> getSmartAccess(String bookingId) async => {
        'bookingId': bookingId,
        'unitCode': 'M-201',
        'pinSet': pinSet,
        'locked': true,
        'attemptsRemaining': 5,
      };

  @override
  Future<Map<String, dynamic>> updatePin(
      String bookingId, String currentPin, {String? newPin}) async {
    lastUpdatedCurrentPin = currentPin;
    lastUpdatedNewPin = newPin;
    return {
      'bookingId': bookingId,
      'unitCode': 'M-201',
      'pinSet': true,
      'locked': true,
      'attemptsRemaining': 5,
      if (newPin == null) 'generatedPin': '888999',
    };
  }

  @override
  Future<Map<String, dynamic>> resetPin(String bookingId, String password,
      {String? newPin}) async {
    if (password == 'wrong') {
      throw Exception('Mật khẩu không đúng');
    }
    lastResetPassword = password;
    lastResetNewPin = newPin;
    return {
      'bookingId': bookingId,
      'unitCode': 'M-201',
      'pinSet': true,
      'locked': true,
      'attemptsRemaining': 5,
      if (newPin == null) 'generatedPin': '654321',
    };
  }
}

void main() {
  testWidgets('Wrong password in reset PIN closes dialog and shows an error',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SmartKeyScreen(
        bookingId: 'booking-1',
        unitNumber: 'M-201',
        apiService: _MockStorageService(),
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

  testWidgets('Reset PIN with custom PIN shows confirm PIN field and validates matching',
      (tester) async {
    final service = _MockStorageService();
    await tester.pumpWidget(MaterialApp(
      home: SmartKeyScreen(
        bookingId: 'booking-1',
        unitNumber: 'M-201',
        apiService: service,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Quên mã PIN?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quên mã PIN?'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu tài khoản'), 'correctpass');

    // Switch to custom PIN mode
    await tester.tap(find.text('Tự đặt mã'));
    await tester.pumpAndSettle();

    // Confirm field should now be visible
    expect(find.widgetWithText(TextFormField, 'Nhập lại mã PIN'), findsOneWidget);

    // Mismatched PIN entry
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mã PIN 6 số'), '123456');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nhập lại mã PIN'), '654321');
    await tester.tap(find.text('Đặt lại PIN'));
    await tester.pumpAndSettle();

    expect(find.text('Mã PIN không khớp'), findsOneWidget);

    // Matched PIN entry
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nhập lại mã PIN'), '123456');
    await tester.tap(find.text('Đặt lại PIN'));
    await tester.pumpAndSettle();

    expect(service.lastResetPassword, equals('correctpass'));
    expect(service.lastResetNewPin, equals('123456'));
    expect(find.text('Đã đặt lại mã PIN, cửa đã được khóa lại'), findsOneWidget);
  });

  testWidgets('Change PIN allows system-generated option and shows generated PIN dialog',
      (tester) async {
    final service = _MockStorageService();
    await tester.pumpWidget(MaterialApp(
      home: SmartKeyScreen(
        bookingId: 'booking-1',
        unitNumber: 'M-201',
        apiService: service,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Đổi mã PIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi mã PIN'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mã PIN hiện tại'), '111111');

    // Switch to system-generated mode
    await tester.tap(find.text('Hệ thống cấp'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đổi mã'));
    await tester.pumpAndSettle();

    expect(service.lastUpdatedCurrentPin, equals('111111'));
    expect(service.lastUpdatedNewPin, isNull);

    // The generated PIN dialog appears
    expect(find.text('Mã PIN của bạn'), findsOneWidget);
    expect(find.text('8  8  8  9  9  9'), findsOneWidget);

    // Tap "Tôi đã ghi nhớ" button to close dialog without auto-filling
    await tester.tap(find.text('Tôi đã ghi nhớ'));
    await tester.pumpAndSettle();

    expect(find.text('Mã PIN của bạn'), findsNothing);

    // User types the PIN into the single unlock field
    await tester.enterText(
        find.widgetWithText(TextField, 'Nhập mã PIN 6 số để mở'), '888999');
    await tester.pumpAndSettle();

    expect(find.text('888999'), findsOneWidget);
  });
}
