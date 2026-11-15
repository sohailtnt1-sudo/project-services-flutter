// Smoke test: the auth screen builds and shows login/signup.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_services/screens/auth_screen.dart';

void main() {
  testWidgets('Auth screen shows AsaanKaam login', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pump();
    expect(find.text('AsaanKaam'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
