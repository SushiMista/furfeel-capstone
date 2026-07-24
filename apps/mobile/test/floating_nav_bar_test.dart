import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/widgets/floating_nav_bar.dart';

const _destinations = [
  FloatingNavDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
  ),
  FloatingNavDestination(
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    label: 'Alerts',
    badgeCount: 3,
  ),
  FloatingNavDestination(
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    label: 'Trends',
  ),
  FloatingNavDestination(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Profile',
  ),
  FloatingNavDestination(
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    label: 'Chat',
  ),
];

Widget bar({
  required int selected,
  required ValueChanged<int> onSelected,
  double textScale = 1.0,
}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        bottomNavigationBar: FloatingNavBar(
          selectedIndex: selected,
          onDestinationSelected: onSelected,
          destinations: _destinations,
          detachLast: true,
        ),
      ),
    );

void main() {
  testWidgets('the detached destination keeps its own index', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(bar(selected: 0, onSelected: (i) => tapped = i));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Chat'));
    expect(tapped, 4);
    await tester.tap(find.bySemanticsLabel('Profile'));
    expect(tapped, 3);
  });

  // The bar draws no text, but every destination must still be reachable and
  // announceable by name — that is the whole cost of going icon-only, so it
  // gets a test rather than a promise.
  testWidgets('every destination keeps an accessible name', (tester) async {
    await tester.pumpWidget(bar(selected: 0, onSelected: (_) {}));
    await tester.pumpAndSettle();

    for (final d in _destinations) {
      // Not drawn...
      expect(find.text(d.label), findsNothing);
      // ...but still announced and findable by name.
      expect(
        find.bySemanticsLabel(RegExp('^${RegExp.escape(d.label)}(,|\$)')),
        findsOneWidget,
      );
    }
    // A badged tab announces its count as a phrase, not a stray number.
    expect(find.bySemanticsLabel('Alerts, 3 new'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // still drawn as the badge
  });

  testWidgets('selection is not carried by colour alone', (tester) async {
    await tester.pumpWidget(bar(selected: 1, onSelected: (_) {}));
    await tester.pumpAndSettle();

    // The selected item swaps to its filled glyph; the rest stay outlined, so
    // the current tab is still readable without colour vision.
    expect(find.byIcon(Icons.notifications), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.home), findsNothing);
  });

  // A fixed-height bar has no give: anything that grows past it fails as a
  // layout error, not a cosmetic one. Narrowest common phone width plus a
  // large text scale (which the badge still honours).
  testWidgets('lays out without overflow on a narrow screen at large text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      bar(selected: 4, onSelected: (_) {}, textScale: 2.0),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
