// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/main.dart';
import 'package:frontend/providers/auth_providers.dart';

void main() {
  testWidgets('shows the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Login to your account'), findsOneWidget);
  });

  test('parses JWT expiration for auto logout', () {
    final exp = (DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 30))
            .millisecondsSinceEpoch ~/
        1000);
    final payload = base64UrlEncode(
      utf8.encode('{"exp": $exp}'),
    );
    final token = 'header.$payload.signature';

    final expiry = AuthNotifier.parseTokenExpiry(token);

    expect(expiry, isNotNull);
    expect(expiry!.difference(DateTime.now().toUtc()).inSeconds,
        inInclusiveRange(29, 30));
  });
}
