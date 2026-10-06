import 'package:flutter_test/flutter_test.dart';
import 'package:storehub_mobile/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StoreHubApp());

    expect(find.text('StoreHub'), findsWidgets);
  });
}
