import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/device_pairing_page.dart';

import 'fakes.dart';

const _dog = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');

Widget app(FakeRepository repo) =>
    MaterialApp(home: DevicePairingPage(repository: repo, dog: _dog));

void main() {
  testWidgets('unpaired dog shows the pair-by-code form and pairs', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('PAIR A HARNESS'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'FURFEEL-DEV-0002');
    await tester.tap(find.text('Pair harness'));
    await tester.pumpAndSettle();

    expect(repo.lastPaired, ('FURFEEL-DEV-0002', 'dog-1'));
    expect(find.text('FURFEEL-DEV-0002'), findsWidgets); // paired card now shown
    expect(find.text('Unpair harness'), findsOneWidget);
  });

  testWidgets('paired device shows connectivity, last sync, and offline help',
      (tester) async {
    final repo = FakeRepository(
      device: Device(
        id: 'device-1',
        dogId: 'dog-1',
        deviceCode: 'FURFEEL-DEV-0001',
        status: 'offline',
        lastSeenAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('offline'), findsOneWidget);
    expect(find.textContaining('Last sync'), findsOneWidget);
    expect(find.textContaining("hasn't checked in"), findsOneWidget);
  });
}
