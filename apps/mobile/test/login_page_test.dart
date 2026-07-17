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

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, ' owner@example.com ');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.tap(find.text('Sign in'));
    // On success the button stays busy (the page pops in production, but here
    // LoginPage is the root route), so the spinner never settles -- use fixed
    // pumps instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

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

  testWidgets('password visibility toggle reveals and re-hides the input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(signIn: (email, password) async => null)),
    );
    await tester.pumpAndSettle();

    TextField password() => tester.widget(find.byType(TextField).last);
    expect(password().obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(password().obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(password().obscureText, isTrue);
  });

  testWidgets('create-account cross-link fires its callback', (tester) async {
    var linked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          signIn: (email, password) async => null,
          onCreateAccount: () => linked = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create account'));
    await tester.pump();
    await tester.tap(find.text('Create account'));
    expect(linked, isTrue);
  });

  testWidgets('cross-link is absent when no callback is provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(signIn: (email, password) async => null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('google button starts OAuth and stays busy on success', (tester) async {
    var started = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          signIn: (email, password) async => null,
          onGoogleSignIn: () async {
            started++;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Continue with Google'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(started, 1);
    // Success means a redirect is coming -- the button stays busy so the
    // user cannot double-launch the flow.
    expect(find.text('Opening Google'), findsOneWidget);
  });

  testWidgets('google button surfaces OAuth errors inline and re-enables', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(
          signIn: (email, password) async => null,
          onGoogleSignIn: () async => 'Could not start Google sign-in.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Continue with Google'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Continue with Google'));
    // Fixed pumps: the inline error's entrance animation schedules delayed
    // timers that pumpAndSettle trips over at teardown.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Could not start Google sign-in.'), findsOneWidget);
    // The inline error pushes the button further down the lazy ListView —
    // scroll it back into build range before asserting it re-enabled.
    await tester.scrollUntilVisible(find.text('Continue with Google'), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('google button is absent when no OAuth callback is provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(signIn: (email, password) async => null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsNothing);
  });
}
