import 'dart:async';

import 'package:flutter/material.dart';
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

  testWidgets('Reset link opens the app password dialog with its token',
      (WidgetTester tester) async {
    final links = StreamController<Uri>();
    addTearDown(links.close);
    await tester.pumpWidget(StoreHubApp(
      restoreSession: () async => null,
      incomingLinks: links.stream,
    ));
    await tester.pumpAndSettle();

    links.add(Uri.parse('storehub://reset-password?token=sample-token'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Set a new password'), findsOneWidget);
    final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Reset link or code'));
    expect(field.controller?.text, 'sample-token');
  });
}

