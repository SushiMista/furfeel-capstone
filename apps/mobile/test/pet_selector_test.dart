import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/widgets/pet_selector.dart';

import 'fakes.dart';

const _biscuit = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');
const _mochi = Dog(id: 'dog-2', ownerUserId: 'user-1', name: 'Mochi');

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders one tile per dog and fires onSelect', (tester) async {
    Dog? picked;
    await tester.pumpWidget(_host(PetSelector(
      dogs: const [_biscuit, _mochi],
      repository: FakeRepository(),
      onSelect: (d) => picked = d,
    )));

    expect(find.text('Biscuit'), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);

    await tester.tap(find.text('Mochi'));
    expect(picked, _mochi);
  });

  testWidgets('the add affordance is present, labelled, and fires', (tester) async {
    var added = 0;
    await tester.pumpWidget(_host(PetSelector(
      dogs: const [_biscuit],
      repository: FakeRepository(),
      onSelect: (_) {},
      onAdd: () => added++,
    )));

    // Labelled for screen readers.
    expect(find.bySemanticsLabel('Add a dog'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    expect(added, 1);
  });

  testWidgets('no add tile when onAdd is null', (tester) async {
    await tester.pumpWidget(_host(PetSelector(
      dogs: const [_biscuit],
      repository: FakeRepository(),
      onSelect: (_) {},
    )));
    expect(find.byIcon(Icons.add), findsNothing);
  });
}
