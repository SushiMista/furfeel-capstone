import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/pages/history_page.dart';

import 'fakes.dart';

const _dog = Dog(id: 'dog-1', ownerUserId: 'user-1', name: 'Biscuit');

class FakeHistoryRepository extends FakeRepository {
  FakeHistoryRepository(
      {List<StressClassification> classifications = const [],
      this.readings = const []})
      : super(dogs: const [_dog]) {
    // Stored on the base field so fetchClassificationsBetween sees it too.
    this.classifications = classifications;
  }

  final List<TelemetryReading> readings;

  @override
  Future<List<StressClassification>> fetchRecentClassifications(String dogId,
          {int limit = 50}) async =>
      classifications;

  @override
  Future<List<TelemetryReading>> fetchRecentReadings(String dogId, {int limit = 20}) async =>
      readings;
}

Widget app(FurFeelRepository repo) => SettingsScope(
      controller: SettingsController(repo),
      child: MaterialApp(home: Scaffold(body: HistoryView(repository: repo, dog: _dog))),
    );

void main() {
  testWidgets('shows the vitals trend, stress timeline, and readings history',
      (tester) async {
    final repo = FakeHistoryRepository(
      classifications: [
        StressClassification(
          id: 'c1',
          dogId: 'dog-1',
          stressLevel: StressLevel.moderate,
          createdAt: DateTime(2026, 7, 11, 8, 30),
          score: 5.0,
        ),
      ],
      readings: [
        TelemetryReading(
          id: 'r1',
          dogId: 'dog-1',
          capturedAt: DateTime(2026, 7, 11, 8, 30),
          heartRateBpm: 130,
          respiratoryRateBpm: 34,
          bodyTemperatureC: 39.1,
        ),
        TelemetryReading(
          id: 'r2',
          dogId: 'dog-1',
          capturedAt: DateTime(2026, 7, 11, 8, 31),
          heartRateBpm: 128,
          respiratoryRateBpm: 33,
          bodyTemperatureC: 39.0,
        ),
      ],
    );
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.text('VITALS TREND'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.text('score 5.0'), findsOneWidget);
    expect(find.textContaining('HR 130'), findsOneWidget);
  });

  testWidgets('empty history is encouraging, not a bare "No data"', (tester) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('No stress readings yet'), findsOneWidget);
    expect(find.textContaining("waiting for Biscuit's harness"), findsOneWidget);
    expect(find.text('VITALS TREND'), findsNothing);
  });
}
