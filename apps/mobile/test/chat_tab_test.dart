import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/chat_tab.dart';

import 'fakes.dart';

const _biscuit = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');
const _mochi = Dog(id: 'dog-2', ownerUserId: 'user-1', name: 'Mochi');

MediaSubmission _submission({
  String id = 'm1',
  String? note,
  String? reviewNote,
  DateTime? reviewedAt,
}) =>
    MediaSubmission(
      id: id,
      dogId: 'dog-1',
      storagePath: 'media/$id.jpg',
      mediaType: 'image',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      note: note,
      reviewNote: reviewNote,
      reviewedAt: reviewedAt,
    );

Widget app(FakeRepository repo, List<Dog> dogs) => SettingsScope(
      controller: SettingsController(repo),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: ChatTab(repository: repo, dogs: dogs)),
      ),
    );

void main() {
  testWidgets('a single-dog owner skips the picker and lands on the threads',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_biscuit],
      mediaSubmissions: [_submission(note: 'He was pacing after the walk')],
    );
    await tester.pumpWidget(app(repo, const [_biscuit]));
    await tester.pumpAndSettle();

    // Straight to the conversation list — no one-row dog picker in the way.
    expect(find.text('Messages'), findsNothing);
    expect(find.text('CONVERSATIONS'), findsOneWidget);
    expect(find.text('He was pacing after the walk'), findsOneWidget);
  });

  testWidgets('a multi-dog owner picks a dog first, then opens its threads',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_biscuit, _mochi],
      mediaSubmissions: [_submission(note: 'Restless this morning')],
    );
    await tester.pumpWidget(app(repo, const [_biscuit, _mochi]));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Biscuit'), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);

    await tester.tap(find.text('Biscuit'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Biscuit'), findsOneWidget);
    expect(find.text('Restless this morning'), findsOneWidget);
  });

  testWidgets('the clinic\'s latest note is pinned above the conversations',
      (tester) async {
    final repo = FakeRepository(
      dogs: const [_biscuit],
      mediaSubmissions: [_submission(note: 'A photo from today')],
    );
    repo.vetNoteFeed = [
      VetNoteFeedItem(
        id: 'n1',
        note: 'Keep the evening walks short this week.',
        createdAt: DateTime.now(),
        authorName: 'Dr. Alex Kim',
      ),
      VetNoteFeedItem(
        id: 'n2',
        note: 'An older note.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        authorName: 'Dr. Alex Kim',
      ),
    ];
    await tester.pumpWidget(app(repo, const [_biscuit]));
    await tester.pumpAndSettle();

    expect(find.text('FROM YOUR CARE TEAM'), findsOneWidget);
    expect(find.text('Keep the evening walks short this week.'), findsOneWidget);
    expect(find.text('Dr. Alex Kim'), findsOneWidget);
    // Only the newest is pinned; the rest are counted, not dumped inline.
    expect(find.text('An older note.'), findsNothing);
    expect(find.textContaining('1 earlier note'), findsOneWidget);
  });

  testWidgets('threads show whether the clinic has replied yet', (tester) async {
    final repo = FakeRepository(
      dogs: const [_biscuit],
      mediaSubmissions: [
        _submission(id: 'm1', note: 'Waiting on this one'),
        _submission(
          id: 'm2',
          note: 'Already looked at',
          reviewNote: 'Looks normal to me.',
          reviewedAt: DateTime.now(),
        ),
      ],
    );
    await tester.pumpWidget(app(repo, const [_biscuit]));
    await tester.pumpAndSettle();

    // Word, not colour alone (docs/19).
    expect(find.text('Awaiting your clinic'), findsOneWidget);
    expect(find.text('Reviewed'), findsOneWidget);
  });

  testWidgets('an empty chat explains how a conversation starts', (tester) async {
    final repo = FakeRepository(dogs: const [_biscuit]);
    await tester.pumpWidget(app(repo, const [_biscuit]));
    await tester.pumpAndSettle();

    expect(find.text('No conversations yet'), findsOneWidget);
    // Honest about the current substrate: a thread hangs off a shared
    // observation, so starting one needs a photo or video.
    expect(find.textContaining('Share a photo or video of Biscuit'),
        findsOneWidget);
    expect(find.text('Share an observation'), findsOneWidget);
  });
}
