import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/screens/home/chat_tab.dart';
import 'package:furfeel_mobile/widgets/alert_card.dart';

import 'fakes.dart';

const _biscuit = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');
const _mochi = Dog(id: 'dog-2', ownerUserId: 'user-1', name: 'Mochi');

Widget wrap(FakeRepository repo, Widget home) => SettingsScope(
      controller: SettingsController(repo),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: home,
      ),
    );

Widget messages(FakeRepository repo, List<Dog> dogs) =>
    wrap(repo, Scaffold(body: ChatTab(repository: repo, dogs: dogs)));

Alert _alert() => Alert(
      id: 'a1',
      dogId: 'dog-1',
      severity: 'warning',
      type: 'moderate_stress',
      message: 'Biscuit seems a bit stressed.',
      status: 'open',
      createdAt: DateTime.now(),
    );

TelemetryReading _reading() => TelemetryReading(
      id: 'r1',
      dogId: 'dog-1',
      capturedAt: DateTime(2026, 11, 5, 15, 8),
      heartRateBpm: 87,
      ambientTemperatureC: 24.6,
    );

void main() {
  testWidgets('Messages lists every dog with its latest message and unread count',
      (tester) async {
    final repo = FakeRepository(dogs: const [_biscuit, _mochi])
      ..dogMessageThreads = [
        DogMessageThread(
          dogId: 'dog-2',
          lastAt: DateTime.now(),
          lastBody: 'Keep him somewhere quiet',
          unreadCount: 2,
        ),
      ];
    await tester.pumpWidget(messages(repo, const [_biscuit, _mochi]));
    await tester.pumpAndSettle();

    expect(find.text('Keep him somewhere quiet'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Start a conversation'), findsOneWidget);
    expect(find.textContaining('For emergencies'), findsOneWidget);
    // Latest conversation sorts first.
    expect(
      tester.getTopLeft(find.text('Mochi')).dy,
      lessThan(tester.getTopLeft(find.text('Biscuit')).dy),
    );
  });

  testWidgets('a message-only conversation works with no photo or video',
      (tester) async {
    final repo = FakeRepository(dogs: const [_biscuit]);
    await tester.pumpWidget(messages(repo, const [_biscuit]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Biscuit'));
    await tester.pumpAndSettle();
    expect(repo.markedReadDogIds, ['dog-1']);

    await tester.enterText(find.byType(TextField), 'He is pacing tonight');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(repo.sentDogMessages.single.body, 'He is pacing tonight');
    expect(repo.sentDogMessages.single.hasMedia, isFalse);
    expect(find.text('He is pacing tonight'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('own and clinic messages are told apart, and only yours are editable',
      (tester) async {
    final repo = FakeRepository(dogs: const [_biscuit])
      ..dogMessages = [
        DogMessage(
          id: 'm1',
          dogId: 'dog-1',
          authorUserId: 'user-1',
          body: 'Mine',
          createdAt: DateTime.now(),
        ),
        DogMessage(
          id: 'm2',
          dogId: 'dog-1',
          authorUserId: 'vet-1',
          authorName: 'Dr. Reyes',
          body: 'From the clinic',
          createdAt: DateTime.now(),
        ),
      ];
    await tester.pumpWidget(wrap(repo, DogChatPage(repository: repo, dog: _biscuit)));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Reyes'), findsOneWidget);

    await tester.longPress(find.text('From the clinic'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);

    await tester.longPress(find.text('Mine'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('a clinic note is pinned above the conversation', (tester) async {
    final repo = FakeRepository(dogs: const [_biscuit])
      ..vetNoteFeed = [
        VetNoteFeedItem(
          id: 'n1',
          note: 'Recheck next week',
          authorName: 'Dr. Reyes',
          createdAt: DateTime.now(),
        ),
      ];
    await tester.pumpWidget(wrap(repo, DogChatPage(repository: repo, dog: _biscuit)));
    await tester.pumpAndSettle();
    expect(find.text('Recheck next week'), findsOneWidget);
  });

  testWidgets('an attached alert can be sent alone, with its reading', (tester) async {
    final repo = FakeRepository(dogs: const [_biscuit]);
    await tester.pumpWidget(wrap(
      repo,
      DogChatPage(
        repository: repo,
        dog: _biscuit,
        alert: _alert(),
        reading: _reading(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Stress level is up'), findsOneWidget);
    expect(find.textContaining('87 bpm · 24.6°C'), findsOneWidget);

    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(repo.sentDogMessages.single.alertId, 'a1');
    expect(repo.sentDogMessages.single.readingId, 'r1');
  });

  testWidgets('removing the alert sends nothing about it', (tester) async {
    final repo = FakeRepository(dogs: const [_biscuit]);
    await tester.pumpWidget(wrap(
      repo,
      DogChatPage(
        repository: repo,
        dog: _biscuit,
        alert: _alert(),
        reading: _reading(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove alert'));
    await tester.pump();
    expect(find.text('Stress level is up'), findsNothing);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send)).onPressed,
        isNull);

    await tester.enterText(find.byType(TextField), 'Just a question');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(repo.sentDogMessages.single.alertId, isNull);
    expect(repo.sentDogMessages.single.readingId, isNull);
  });

  testWidgets('Message vet is on open alerts and hands over the alert', (tester) async {
    Alert? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AlertCard(alert: _alert(), onMessageVet: (a) => tapped = a),
      ),
    ));
    await tester.tap(find.text('Message vet'));
    expect(tapped?.id, 'a1');
  });
}
