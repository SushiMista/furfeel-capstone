import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/media_thread_page.dart';

import 'fakes.dart';

const _dog = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');

MediaSubmission submission({String? note, String? reviewNote, DateTime? reviewedAt}) =>
    MediaSubmission(
      id: 'media-1',
      dogId: 'dog-1',
      storagePath: 'dogs/dog-1/obs.mp4',
      mediaType: 'video',
      createdAt: DateTime(2026, 7, 16, 9),
      note: note,
      reviewNote: reviewNote,
      reviewedAt: reviewedAt,
    );

void main() {
  testWidgets('shows the owner note, the vet review, and thread replies',
      (tester) async {
    final repo = FakeRepository()
      ..mediaMessages = [
        MediaMessage(
          id: 'm1',
          mediaSubmissionId: 'media-1',
          authorUserId: 'vet-1',
          authorName: 'Dr. Kim',
          body: 'Thanks — this angle helps a lot.',
          createdAt: DateTime(2026, 7, 16, 11),
        ),
      ];
    await tester.pumpWidget(MaterialApp(
      home: MediaThreadPage(
        repository: repo,
        dog: _dog,
        submission: submission(
          note: 'He was pacing all evening',
          reviewNote: 'Looks like normal excitement to us',
          reviewedAt: DateTime(2026, 7, 16, 10),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('He was pacing all evening'), findsOneWidget);
    expect(find.text('Looks like normal excitement to us'), findsOneWidget);
    expect(find.text('Thanks — this angle helps a lot.'), findsOneWidget);
    expect(find.text('Dr. Kim'), findsOneWidget);
  });

  testWidgets('owner can reply back and forth like an email chain', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(MaterialApp(
      home: MediaThreadPage(
        repository: repo,
        dog: _dog,
        submission: submission(reviewNote: 'All looks fine', reviewedAt: DateTime(2026, 7, 16)),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField), 'Thank you! He calmed down after dinner.');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(repo.sentMediaMessages,
        [('media-1', 'Thank you! He calmed down after dinner.')]);
    expect(find.text('Thank you! He calmed down after dinner.'), findsOneWidget);
  });
}
