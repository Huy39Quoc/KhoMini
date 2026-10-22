import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/screens/admin/role_permission_screen.dart';

void main() {
  testWidgets('RolePermissionScreen renders without exceptions', (WidgetTester tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      fail('Flutter exception caught: ${details.exceptionAsString()}');
    };

    await tester.pumpWidget(
      const MaterialApp(
        home: RolePermissionScreen(),
      ),
    );
    await tester.pump();
    expect(find.text('Vai trò & quyền hạn'), findsOneWidget);
  });
}
