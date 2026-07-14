import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/observation_page.dart';

import 'fakes.dart';

const _dog = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');

void main() {
  testWidgets('labels submissions as supplementary — never a classifier input',
      (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(
        MaterialApp(home: ObservationPage(repository: repo, dog: _dog)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not used by the stress classifier'),
      findsOneWidget,
    );
    // Share requires a picked file — button disabled until then.
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('lists past submissions with review status + clinic annotation',
      (tester) async {
    final repo = FakeRepository(
      mediaSubmissions: [
        MediaSubmission(
          id: 'm1',
          dogId: 'dog-1',
          storagePath: 'dogs/dog-1/obs-1.jpg',
          mediaType: 'image',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          note: 'Pacing near the door',
          reviewedAt: DateTime.now(),
          reviewNote: 'Thanks — looks like mild separation stress.',
        ),
        MediaSubmission(
          id: 'm2',
          dogId: 'dog-1',
          storagePath: 'dogs/dog-1/obs-2.mp4',
          mediaType: 'video',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    );
    await tester.pumpWidget(
        MaterialApp(home: ObservationPage(repository: repo, dog: _dog)));
    await tester.pumpAndSettle();

    expect(find.text('Pacing near the door'), findsOneWidget);
    expect(find.text('Reviewed'), findsOneWidget);
    expect(find.text('Awaiting review'), findsOneWidget);
    expect(find.textContaining('mild separation stress'), findsOneWidget);
  });
}
