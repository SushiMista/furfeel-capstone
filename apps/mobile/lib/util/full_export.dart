import 'dart:convert';

import '../data/furfeel_repository.dart';
import '../models/models.dart';

/// ADDED (improvement pass step 14, docs/12 privacy story): "download
/// everything about my dog" — one machine-readable JSON archive of every
/// record the owner can already read under RLS. Pure builder + a paging
/// fetcher so nothing hides behind the PostgREST row cap.

/// Fetches ALL readings for a dog by paging backwards through
/// fetchReadingsBetween (the per-call cap is a PostgREST page, not the export
/// limit). Oldest-first result.
Future<List<TelemetryReading>> fetchAllReadings(
  FurFeelRepository repo,
  String dogId, {
  int pageSize = 1000,
}) async {
  final all = <TelemetryReading>[];
  var to = DateTime.now().add(const Duration(days: 1));
  final from = DateTime.utc(2000);
  while (true) {
    final page =
        await repo.fetchReadingsBetween(dogId, from, to, limit: pageSize);
    if (page.isEmpty) break;
    all.insertAll(0, page);
    if (page.length < pageSize) break;
    // Next page: strictly before the oldest row we have.
    to = page.first.capturedAt.subtract(const Duration(milliseconds: 1));
  }
  return all;
}

/// Same paging walk for classifications.
Future<List<StressClassification>> fetchAllClassifications(
  FurFeelRepository repo,
  String dogId, {
  int pageSize = 2000,
}) async {
  final all = <StressClassification>[];
  var to = DateTime.now().add(const Duration(days: 1));
  final from = DateTime.utc(2000);
  while (true) {
    final page =
        await repo.fetchClassificationsBetween(dogId, from, to, limit: pageSize);
    if (page.isEmpty) break;
    all.insertAll(0, page);
    if (page.length < pageSize) break;
    to = page.first.createdAt.subtract(const Duration(milliseconds: 1));
  }
  return all;
}

String _ts(DateTime t) => t.toUtc().toIso8601String();

/// Builds the archive. Everything is data the signed-in owner can already
/// read; media is included as metadata (paths + notes), not bytes — the app
/// can't bundle private-bucket objects into one file, and the paths let a
/// person request/locate the originals.
String buildFullExportJson({
  required Dog dog,
  required UserProfile owner,
  DogBaseline? baseline,
  Device? device,
  required List<TelemetryReading> readings,
  required List<StressClassification> classifications,
  required List<Alert> alerts,
  required List<VetNote> vetNotes,
  required List<StressLabelEntry> stressLabels,
  required List<MediaSubmission> media,
}) {
  final now = DateTime.now();
  return const JsonEncoder.withIndent('  ').convert({
    'export': {
      'generated_at': _ts(now),
      'app': 'FurFeel owner app',
      'disclaimer':
          'Decision-support monitoring data, not a medical record or diagnosis.',
      'counts': {
        'readings': readings.length,
        'classifications': classifications.length,
        'alerts': alerts.length,
        'vet_notes': vetNotes.length,
        'stress_labels': stressLabels.length,
        'media_submissions': media.length,
      },
    },
    'owner': {
      'name': owner.name,
      'email': owner.email,
      'phone': owner.phone,
      'emergency_contact': owner.emergencyContact,
    },
    'dog': {
      'id': dog.id,
      'name': dog.name,
      'breed': dog.breed,
      'birthdate': dog.birthdate,
      'sex': dog.sex,
      'weight_kg': dog.weightKg,
      'notes': dog.notes,
      'clinic_id': dog.clinicId,
    },
    'baseline': baseline == null
        ? null
        : {
            'resting_heart_rate_bpm': baseline.restingHeartRateBpm,
            'resting_respiratory_rate_bpm': baseline.restingRespiratoryRateBpm,
            'normal_body_temperature_c': baseline.normalBodyTemperatureC,
          },
    'device': device == null
        ? null
        : {
            'device_code': device.deviceCode,
            'status': device.status,
            'last_seen_at': device.lastSeenAt == null ? null : _ts(device.lastSeenAt!),
            'battery_percent': device.batteryPercent,
          },
    'telemetry_readings': [
      for (final r in readings)
        {
          'captured_at': _ts(r.capturedAt),
          'heart_rate_bpm': r.heartRateBpm,
          'respiratory_rate_bpm': r.respiratoryRateBpm,
          'body_temperature_c': r.bodyTemperatureC,
          'motion_activity': r.motionActivity,
          'posture': r.posture,
          'ambient_temperature_c': r.ambientTemperatureC,
          'humidity_percent': r.humidityPercent,
          'battery_percent': r.batteryPercent,
        },
    ],
    'stress_classifications': [
      for (final c in classifications)
        {
          'created_at': _ts(c.createdAt),
          'stress_level': c.stressLevel.name,
          'score': c.score,
          'model_version': c.modelVersion,
          'reasons': c.reasons,
        },
    ],
    'alerts': [
      for (final a in alerts)
        {
          'created_at': _ts(a.createdAt),
          'severity': a.severity,
          'type': a.type,
          'message': a.message,
          'status': a.status,
          'acknowledged_at': a.acknowledgedAt == null ? null : _ts(a.acknowledgedAt!),
        },
    ],
    'vet_notes': [
      for (final n in vetNotes)
        {
          'created_at': _ts(n.createdAt),
          'author': n.authorName,
          'note': n.note,
        },
    ],
    'stress_labels': [
      for (final l in stressLabels)
        {
          'created_at': _ts(l.createdAt),
          'confirmed_level': l.confirmedLevel.name,
          'agreed_with_model': l.agreedWithModel,
          'note': l.note,
        },
    ],
    'media_submissions': [
      for (final m in media)
        {
          'created_at': _ts(m.createdAt),
          'media_type': m.mediaType,
          'storage_path': m.storagePath,
          'note': m.note,
          'review_note': m.reviewNote,
          'reviewed_at': m.reviewedAt == null ? null : _ts(m.reviewedAt!),
        },
    ],
  });
}
