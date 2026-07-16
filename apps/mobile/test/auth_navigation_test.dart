import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the "stuck screen" class of bug (see also
/// login_page_test.dart's sign-in case): main.dart drives top-level routing
/// with a StreamBuilder on the auth stream inside MaterialApp.home, swapping
/// Welcome <-> RootShell. Any screen pushed on top of that (LoginPage,
/// AccountPage, ...) sits above the StreamBuilder's route, so when the
/// stream flips underneath it, the pushed screen is left stranded unless the
/// auth listener explicitly pops back to the first route.
///
/// This reproduces the shape of _FurFeelAppState (private, coupled to the
/// real Supabase singleton, not directly testable) with a fake auth stream,
/// to prove the pop-on-signed-out fix without needing Supabase.
void main() {
  testWidgets('signing out from a pushed screen returns to the signed-out root',
      (tester) async {
    final authEvents = StreamController<bool>.broadcast(); // true = signed in
    var signedIn = true;
    final navigatorKey = GlobalKey<NavigatorState>();
    addTearDown(authEvents.close);

    authEvents.stream.listen((value) {
      signedIn = value;
      if (!value) {
        // Mirrors main.dart's AuthChangeEvent.signedOut handling.
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: StreamBuilder<bool>(
          stream: authEvents.stream,
          initialData: signedIn,
          builder: (context, snapshot) {
            return snapshot.data == true
                ? Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Account')),
                              body: Center(
                                child: ElevatedButton(
                                  onPressed: () => authEvents.add(false),
                                  child: const Text('Sign out'),
                                ),
                              ),
                            ),
                          ),
                        ),
                        child: const Text('Open account'),
                      ),
                    ),
                  )
                : const Scaffold(body: Center(child: Text('Welcome')));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open account'));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    // Regression check: signing out must pop the pushed screen off the
    // stack so the signed-out root becomes visible -- otherwise the user is
    // stuck staring at a half-cleared account page (see bug report).
    expect(find.text('Account'), findsNothing);
    expect(find.text('Welcome'), findsOneWidget);
  });
}
