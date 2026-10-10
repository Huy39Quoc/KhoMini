import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(StoreHubApp(restoreSession: () async => null));
    await tester.pumpAndSettle();

    expect(find.text('StoreHub'), findsWidgets);
  });

  testWidgets('Session recovery offers retry when the server is unavailable',
      (WidgetTester tester) async {
    var attempts = 0;
    await tester.pumpWidget(StoreHubApp(restoreSession: () async {
      attempts++;
      if (attempts == 1) throw Exception('offline');
      return null;
    }));
    await tester.pumpAndSettle();

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('StoreHub'), findsWidgets);
  });
}
