import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/pages/login_page.dart';

void main() {
  testWidgets('submits credentials and shows no error on success', (tester) async {
    String? seenEmail;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          signIn: (email, password) async {
            seenEmail = email;
            return null;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, ' owner@example.com ');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(seenEmail, 'owner@example.com'); // trimmed
    expect(find.textContaining('Invalid'), findsNothing);
  });

  testWidgets('surfaces the sign-in error message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(signIn: (email, password) async => 'Invalid login credentials'),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'owner@example.com');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid login credentials'), findsOneWidget);
  });

  testWidgets('pops back to the underlying screen after a successful sign-in', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LoginPage(signIn: (email, password) async => null),
                ),
              ),
              child: const Text('I already have an account'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'owner@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // Regression check: a successful sign-in must pop LoginPage off the stack
    // so the auth-stream-driven home screen underneath becomes visible again --
    // otherwise the user is stuck staring at a dead login form (see bug report).
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
