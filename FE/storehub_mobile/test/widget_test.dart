import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StoreHubApp());

    // Verify that the login screen title exists
    expect(find.text('StoreHub'), findsWidgets);
  });
}
