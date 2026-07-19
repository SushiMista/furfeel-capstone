import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// ADDED (offline resilience, docs/04): last-known status snapshot so the app
/// opens to *something* without network — the dogs list plus the selected
/// dog's latest reading + classification — clearly labeled as stale by the
/// RootShell banner rather than pretending to be live. Maps use the same
/// snake_case keys as the Supabase rows so the models' own fromMap parsers
/// re-hydrate them.
class CachedStatus {
  const CachedStatus({
    required this.dogs,
    required this.selectedDogId,
    required this.savedAt,
    this.reading,
    this.classification,
  });

  final List<Dog> dogs;
  final String? selectedDogId;
  final DateTime savedAt;
  final TelemetryReading? reading;
  final StressClassification? classification;
}

abstract final class StatusCache {
  static const _key = 'furfeel_last_status_v1';

  static Map<String, dynamic> _dogMap(Dog d) => {
        'id': d.id,
        'owner_user_id': d.ownerUserId,
        'clinic_id': d.clinicId,
        'name': d.name,
        'breed': d.breed,
        'birthdate': d.birthdate,
        'sex': d.sex,
        'weight_kg': d.weightKg,
        'notes': d.notes,
        'photo_path': d.photoPath,
      };

  static Map<String, dynamic> _readingMap(TelemetryReading r) => {
        'id': r.id,
        'dog_id': r.dogId,
        'captured_at': r.capturedAt.toUtc().toIso8601String(),
        'heart_rate_bpm': r.heartRateBpm,
        'body_temperature_c': r.bodyTemperatureC,
        'respiratory_rate_bpm': r.respiratoryRateBpm,
        'motion_activity': r.motionActivity,
        'posture': r.posture,
        'ambient_temperature_c': r.ambientTemperatureC,
        'humidity_percent': r.humidityPercent,
        'battery_percent': r.batteryPercent,
      };

  static Map<String, dynamic> _classificationMap(StressClassification c) => {
        'id': c.id,
        'dog_id': c.dogId,
        'stress_level': c.stressLevel.name,
        'created_at': c.createdAt.toUtc().toIso8601String(),
        'score': c.score,
        'model_version': c.modelVersion,
        'reasons': c.reasons,
      };

  static Future<void> save({
    required List<Dog> dogs,
    required String? selectedDogId,
    TelemetryReading? reading,
    StressClassification? classification,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'v': 1,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'selected_dog_id': selectedDogId,
        'dogs': dogs.map(_dogMap).toList(),
        'reading': reading == null ? null : _readingMap(reading),
        'classification':
            classification == null ? null : _classificationMap(classification),
      }),
    );
  }

  static Future<CachedStatus?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['v'] != 1) return null;
      return CachedStatus(
        dogs: (map['dogs'] as List)
            .map((d) => Dog.fromMap(Map<String, dynamic>.from(d as Map)))
            .toList(),
        selectedDogId: map['selected_dog_id'] as String?,
        savedAt: DateTime.parse(map['saved_at'] as String).toLocal(),
        reading: map['reading'] == null
            ? null
            : TelemetryReading.fromMap(
                Map<String, dynamic>.from(map['reading'] as Map)),
        classification: map['classification'] == null
            ? null
            : StressClassification.fromMap(
                Map<String, dynamic>.from(map['classification'] as Map)),
      );
    } catch (_) {
      return null; // a corrupt cache is never worth an error screen
    }
  }

  /// Sign-out hygiene: cached readings belong to the signed-in account.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
