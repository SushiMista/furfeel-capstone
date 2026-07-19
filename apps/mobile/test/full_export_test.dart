import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/demo_repository.dart';
import 'package:furfeel_mobile/util/full_export.dart';

/// Step 14: the "download everything" archive (docs/12 privacy story).
void main() {
  test('paging fetchers walk past the per-call cap', () async {
    final repo = DemoRepository(); // ~1000 readings over a week
    final all = await fetchAllReadings(repo, 'demo-dog', pageSize: 100);
    final direct = await repo.fetchReadingsBetween(
        'demo-dog', DateTime(2000), DateTime.now(), limit: 100000);
    expect(all.length, direct.length, reason: 'paging must not drop or dup rows');
    // Oldest-first with no duplicates.
    expect(all.map((r) => r.id).toSet().length, all.length);
    expect(all.first.capturedAt.isBefore(all.last.capturedAt), isTrue);
  });

  test('archive JSON is complete, valid, and observational', () async {
    final repo = DemoRepository();
    final readings = await fetchAllReadings(repo, 'demo-dog');
    final classifications = await fetchAllClassifications(repo, 'demo-dog');
    final json = buildFullExportJson(
      dog: (await repo.fetchDogs()).single,
      owner: await repo.fetchMyProfile(),
      baseline: null,
      device: await repo.fetchDeviceForDog('demo-dog'),
      readings: readings,
      classifications: classifications,
      alerts: await repo.fetchAlerts('demo-dog'),
      vetNotes: await repo.fetchVetNotes('demo-dog'),
      stressLabels: const [],
      media: const [],
    );
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['export']['counts']['readings'], readings.length);
    expect((decoded['telemetry_readings'] as List).length, readings.length);
    expect((decoded['stress_classifications'] as List).length,
        classifications.length);
    expect(decoded['dog']['name'], 'Buddy');
    expect(decoded['export']['disclaimer'], contains('not a medical record'));
  });
}
