import 'dart:math';
import 'dart:typed_data';

import '../insights/biometric_bands.g.dart';
import '../models/models.dart';
import 'furfeel_repository.dart';

/// ADDED (improvement pass step 10): Demo mode. A fully local repository with
/// a realistic generated week of telemetry so an evaluator can explore the
/// whole owner app with **no hardware, no account, and no network**. All data
/// is synthetic and clearly labeled by the shell's demo banner; nothing is
/// ever written to Supabase. Deterministic (fixed seed) so every demo run
/// tells the same story:
///  - calm nights, lively mornings and evenings (a normal dog day),
///  - one warm afternoon yesterday that climbed to `moderate` and raised an
///    alert (left open so the Alerts tab has something to acknowledge).
class DemoRepository implements FurFeelRepository {
  DemoRepository() {
    _generate();
  }

  static const _dogId = 'demo-dog';

  final Dog _dog = Dog(
    id: _dogId,
    ownerUserId: 'demo-user',
    name: 'Buddy',
    breed: 'Aspin',
    sex: 'male',
    weightKg: 14.5,
    birthdate: '${DateTime.now().year - 3}-03-14',
    notes: 'Demo dog — all readings are sample data.',
  );

  final List<TelemetryReading> _readings = [];
  final List<StressClassification> _classifications = [];
  final List<Alert> _alerts = [];
  final List<MediaSubmission> _media = [];
  final UserProfile _profile = const UserProfile(
    id: 'demo-user',
    name: 'Demo Explorer',
    email: 'demo@furfeel.example',
  );
  UserSettings _settings = const UserSettings(theme: 'light');

  /// One reading every 10 minutes for the last 7 days.
  void _generate() {
    final rng = Random(7);
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    var t = start;
    var i = 0;
    while (t.isBefore(now)) {
      final hour = t.hour + t.minute / 60.0;
      // Daily rhythm: resting at night, active 7–9 and 17–19.
      final activity = switch (hour) {
        >= 22 || < 6 => 0.05 + rng.nextDouble() * 0.08,
        >= 7 && < 9 => 0.45 + rng.nextDouble() * 0.3,
        >= 17 && < 19 => 0.4 + rng.nextDouble() * 0.35,
        _ => 0.15 + rng.nextDouble() * 0.2,
      };
      // Yesterday 13:00–15:00: a warm spell — the demo's stress story.
      final yesterday = now.subtract(const Duration(days: 1));
      final isHotSpell = t.year == yesterday.year &&
          t.month == yesterday.month &&
          t.day == yesterday.day &&
          hour >= 13 &&
          hour < 15;
      final ambient = isHotSpell
          ? 33.0 + rng.nextDouble() * 1.5
          : 26.0 + 3 * sin((hour - 4) / 24 * 2 * pi) + rng.nextDouble();
      final hr = isHotSpell
          ? (kGlobalRestingHr * (1.25 + rng.nextDouble() * 0.15)).round()
          : (kGlobalRestingHr * (0.85 + activity * 0.5 + rng.nextDouble() * 0.1))
              .round();
      final rr = isHotSpell
          ? (kGlobalRestingRr * (1.5 + rng.nextDouble() * 0.4)).round()
          : (kGlobalRestingRr * (0.8 + activity * 0.6 + rng.nextDouble() * 0.15))
              .round();

      final reading = TelemetryReading(
        id: 'demo-r$i',
        dogId: _dogId,
        capturedAt: t,
        heartRateBpm: hr,
        respiratoryRateBpm: rr,
        bodyTemperatureC:
            double.parse((38.4 + activity * 0.5 + (isHotSpell ? 0.5 : 0)).toStringAsFixed(1)),
        motionActivity: double.parse(activity.toStringAsFixed(3)),
        posture: activity > 0.4 ? 'moving' : (activity < 0.12 ? 'lying' : 'standing'),
        ambientTemperatureC: double.parse(ambient.toStringAsFixed(1)),
        humidityPercent: double.parse((60 + rng.nextDouble() * 15).toStringAsFixed(1)),
        batteryPercent: 96 - (i ~/ 120),
      );
      _readings.add(reading);

      // Simple rule-v1-shaped scoring for the demo (same tiers, no trend rule).
      var score = 0;
      final reasons = <String>[];
      final hrRatio = hr / kGlobalRestingHr;
      if (hrRatio >= 1.6) {
        score += 3;
        reasons.add('heart_rate_elevated');
      } else if (hrRatio >= 1.35) {
        score += 2;
        reasons.add('heart_rate_elevated');
      } else if (hrRatio >= 1.15) {
        score += 1;
        reasons.add('heart_rate_elevated');
      }
      final rrRatio = rr / kGlobalRestingRr;
      if (rrRatio >= 1.8) {
        score += 2;
        reasons.add('respiratory_elevated');
      } else if (rrRatio >= 1.3) {
        score += 1;
        reasons.add('respiratory_elevated');
      }
      if (activity >= 0.8) {
        score += 2;
        reasons.add('motion_restlessness');
      } else if (activity >= 0.6) {
        score += 1;
        reasons.add('motion_restlessness');
      }
      if (ambient > kHotAmbientAboveC) {
        score += 1;
        reasons.add('environmental_heat');
      }
      final level = score >= 7
          ? StressLevel.high
          : score >= 4
              ? StressLevel.moderate
              : score >= 2
                  ? StressLevel.mild
                  : StressLevel.calm;
      _classifications.add(StressClassification(
        id: 'demo-c$i',
        dogId: _dogId,
        stressLevel: level,
        createdAt: t,
        score: score.toDouble(),
        modelVersion: 'rule-v1 (demo)',
        reasons: reasons,
      ));
      t = t.add(const Duration(minutes: 10));
      i += 1;
    }

    // The hot spell's alert, still open so Acknowledge is demonstrable.
    final spell = _classifications.lastWhere(
      (c) => c.stressLevel == StressLevel.moderate,
      orElse: () => _classifications.last,
    );
    _alerts.add(Alert(
      id: 'demo-a1',
      dogId: _dogId,
      severity: 'warning',
      type: 'moderate_stress',
      message: 'Buddy seemed quite stressed for a while — it was warm and they '
          'were breathing fast. This is sample data from Demo mode.',
      status: 'open',
      createdAt: spell.createdAt,
    ));
  }

  // ---- Dogs ----
  @override
  Future<Dog?> fetchFirstDog() async => _dog;
  @override
  Future<List<Dog>> fetchDogs() async => [_dog];
  @override
  Future<Dog> createDog(DogDraft draft) async =>
      throw const FurFeelDataException('Demo mode shows a sample dog — create a free account to add your own.');
  @override
  Future<Dog> updateDog(String dogId, DogDraft draft) async =>
      throw const FurFeelDataException('Demo mode is read-only — create a free account to manage a real dog.');
  @override
  Future<void> deleteDog(String dogId) async =>
      throw const FurFeelDataException('Demo mode is read-only.');
  @override
  Future<Dog> setDogPhoto(String dogId, Uint8List bytes, String fileExtension) async =>
      throw const FurFeelDataException('Demo mode is read-only.');
  @override
  Future<String> getSignedMediaUrl(String storagePath) async =>
      throw const FurFeelDataException('No media in Demo mode.');
  @override
  Future<List<Clinic>> fetchClinics() async => const [
        Clinic(id: 'demo-clinic', name: 'FurFeel Demo Veterinary Clinic'),
      ];

  // ---- Telemetry ----
  @override
  Future<TelemetryReading?> fetchLatestReading(String dogId) async => _readings.last;
  @override
  Future<StressClassification?> fetchLatestClassification(String dogId) async =>
      _classifications.last;
  @override
  Future<List<TelemetryReading>> fetchRecentReadings(String dogId, {int limit = 20}) async =>
      _readings.reversed.take(limit).toList();
  @override
  Future<List<TelemetryReading>> fetchReadingsBetween(
    String dogId,
    DateTime from,
    DateTime to, {
    int limit = 1000,
  }) async =>
      _readings
          .where((r) => !r.capturedAt.isBefore(from) && !r.capturedAt.isAfter(to))
          .toList();
  @override
  Future<List<StressClassification>> fetchRecentClassifications(String dogId,
          {int limit = 50}) async =>
      _classifications.reversed.take(limit).toList();
  @override
  Future<List<StressClassification>> fetchClassificationsBetween(
    String dogId,
    DateTime from,
    DateTime to, {
    int limit = 2000,
  }) async =>
      _classifications
          .where((c) => !c.createdAt.isBefore(from) && !c.createdAt.isAfter(to))
          .toList();
  @override
  Future<List<Alert>> fetchAlerts(String dogId, {int limit = 20}) async =>
      _alerts.reversed.take(limit).toList();

  @override
  Future<List<DailyStressSummary>> fetchDailyStressSummary(String dogId,
      {int days = 14}) async {
    final byDay = <String, Map<StressLevel, int>>{};
    for (final c in _classifications) {
      final key = '${c.createdAt.year}-${c.createdAt.month.toString().padLeft(2, '0')}-'
          '${c.createdAt.day.toString().padLeft(2, '0')}';
      final counts = byDay.putIfAbsent(key, () => {});
      counts[c.stressLevel] = (counts[c.stressLevel] ?? 0) + 1;
    }
    final keys = byDay.keys.toList()..sort();
    return [
      for (final k in keys.reversed.take(days).toList().reversed)
        DailyStressSummary(
          day: DateTime.parse(k),
          calm: byDay[k]![StressLevel.calm] ?? 0,
          mild: byDay[k]![StressLevel.mild] ?? 0,
          moderate: byDay[k]![StressLevel.moderate] ?? 0,
          high: byDay[k]![StressLevel.high] ?? 0,
        ),
    ];
  }

  @override
  Future<List<HourlyStressBucket>> fetchHourlyStressPattern(String dogId,
      {int days = 14}) async {
    final byHour = <int, List<StressClassification>>{};
    for (final c in _classifications) {
      byHour.putIfAbsent(c.createdAt.hour, () => []).add(c);
    }
    return [
      for (final h in (byHour.keys.toList()..sort()))
        HourlyStressBucket(
          hour: h,
          calm: byHour[h]!.where((c) => c.stressLevel == StressLevel.calm).length,
          mild: byHour[h]!.where((c) => c.stressLevel == StressLevel.mild).length,
          moderate:
              byHour[h]!.where((c) => c.stressLevel == StressLevel.moderate).length,
          high: byHour[h]!.where((c) => c.stressLevel == StressLevel.high).length,
        ),
    ];
  }

  @override
  Future<Alert?> acknowledgeAlert(String alertId) async {
    final i = _alerts.indexWhere((a) => a.id == alertId && a.status == 'open');
    if (i < 0) return null;
    final updated = Alert(
      id: _alerts[i].id,
      dogId: _alerts[i].dogId,
      severity: _alerts[i].severity,
      type: _alerts[i].type,
      message: _alerts[i].message,
      status: 'acknowledged',
      createdAt: _alerts[i].createdAt,
      acknowledgedBy: 'demo-user',
      acknowledgedAt: DateTime.now(),
    );
    _alerts[i] = updated;
    return updated;
  }

  // ---- Device ----
  @override
  Future<Device?> fetchDeviceForDog(String dogId) async => Device(
        id: 'demo-device',
        dogId: _dogId,
        deviceCode: 'FF-DEMO-001',
        status: 'active',
        lastSeenAt: _readings.last.capturedAt,
        firmwareVersion: 'demo',
        batteryPercent: _readings.last.batteryPercent,
      );
  @override
  Future<Device> pairDevice(String deviceCode, String dogId) async =>
      throw const FurFeelDataException('Demo mode already has its sample harness paired.');
  @override
  Future<void> unpairDevice(String deviceId) async =>
      throw const FurFeelDataException('Demo mode is read-only.');
  @override
  Future<DogBaseline?> fetchBaseline(String dogId) async => null;

  // ---- Vet review ----
  @override
  Future<List<VetNote>> fetchVetNotes(String dogId, {int limit = 50}) async => [
        VetNote(
          id: 'demo-n1',
          dogId: _dogId,
          authorName: 'Demo Veterinarian',
          note: 'Sample note: Buddy handled the warm afternoon well — keep water '
              'available on hot days. (Demo data, not real veterinary advice.)',
          createdAt: DateTime.now().subtract(const Duration(hours: 20)),
        ),
      ];
  @override
  Future<List<VetNoteFeedItem>> fetchVetNoteFeed(String dogId, {int limit = 20}) async => [
        VetNoteFeedItem(
          id: 'demo-n1',
          note: 'Sample note: Buddy handled the warm afternoon well — keep water '
              'available on hot days. (Demo data, not real veterinary advice.)',
          createdAt: DateTime.now().subtract(const Duration(hours: 20)),
          authorName: 'Demo Veterinarian',
        ),
      ];
  @override
  Future<List<StressLabelEntry>> fetchStressLabels(String dogId, {int limit = 50}) async =>
      const [];

  @override
  Future<List<CareGuidance>> fetchCareGuidance() async => const [
        CareGuidance(
          stressLevel: StressLevel.calm,
          title: 'Keep up the good routine',
          body: 'Buddy looks comfortable. Fresh water, shade, and the usual '
              'walks keep it that way. (Sample guidance — demo data.)',
        ),
        CareGuidance(
          stressLevel: StressLevel.moderate,
          title: 'Offer a calm, cool spot',
          body: 'Move to a cooler, quieter area and offer water. If this keeps '
              'happening, mention it to your veterinarian. (Sample guidance.)',
        ),
        CareGuidance(
          contextKey: 'hot_stressed',
          title: 'Beat the heat',
          body: 'It is warm and Buddy seems tense — shade, water, and a rest '
              'break usually help. (Sample guidance.)',
        ),
      ];

  @override
  Future<WellnessSnapshot?> fetchWellness(String dogId, DateTime day) async {
    final dayClassifications = _classifications
        .where((c) =>
            c.createdAt.year == day.year &&
            c.createdAt.month == day.month &&
            c.createdAt.day == day.day)
        .toList();
    if (dayClassifications.isEmpty) return null;
    final calm = dayClassifications
            .where((c) => c.stressLevel == StressLevel.calm)
            .length /
        dayClassifications.length;
    final readings = _readings.where((r) =>
        r.capturedAt.year == day.year &&
        r.capturedAt.month == day.month &&
        r.capturedAt.day == day.day);
    final active =
        readings.where((r) => (r.motionActivity ?? 0) >= 0.4).length /
            max(1, readings.length);
    final rest = readings.where((r) => (r.motionActivity ?? 0) < 0.15).length /
        max(1, readings.length);
    final score = (60 * calm + 40 * (1 - (active - 0.30).abs())).round().clamp(0, 100);
    return WellnessSnapshot(
      score: score,
      calmPercent: calm * 100,
      activePercent: active * 100,
      restPercent: rest * 100,
      alertCount: _alerts
          .where((a) =>
              a.createdAt.year == day.year &&
              a.createdAt.month == day.month &&
              a.createdAt.day == day.day)
          .length,
      sampleCount: dayClassifications.length,
    );
  }

  @override
  Future<DogOverview> fetchDogOverview(Dog dog) async => DogOverview(
        dog: dog,
        reading: _readings.last,
        classification: _classifications.last,
        device: await fetchDeviceForDog(dog.id),
        wellness: await fetchWellness(dog.id, DateTime.now()),
      );

  // ---- Media ----
  @override
  Future<List<MediaMessage>> fetchMediaMessages(String mediaSubmissionId) async => const [];
  @override
  Future<MediaMessage> sendMediaMessage(String mediaSubmissionId, String body) async =>
      throw const FurFeelDataException('Demo mode is read-only.');
  @override
  Future<List<MediaSubmission>> fetchMediaSubmissions(String dogId, {int limit = 50}) async =>
      List.of(_media);
  @override
  Future<MediaSubmission> submitObservation({
    required String dogId,
    required Uint8List bytes,
    required String fileExtension,
    required String mediaType,
    String? note,
  }) async =>
      throw const FurFeelDataException(
          'Demo mode cannot upload media — create a free account to share observations.');

  // ---- Consent: the gate protects real monitoring data; the demo is synthetic. ----
  @override
  Future<bool> hasAcceptedConsent(String policyVersion) async => true;
  @override
  Future<void> acceptConsent(String policyVersion) async {}

  @override
  Future<void> registerPushToken(String platform, String token) async {}

  // ---- Account ----
  @override
  Future<UserProfile> fetchMyProfile() async => _profile;
  @override
  Future<UserProfile> updateMyName(String name) async => _profile;
  @override
  Future<UserProfile> updateMyPhone(String? phone) async => _profile;
  @override
  Future<UserProfile> updateMyEmergencyContact(String? contact) async => _profile;
  @override
  Future<UserProfile> setMyAvatar(Uint8List bytes, String fileExtension) async =>
      throw const FurFeelDataException('Demo mode is read-only.');
  @override
  Future<String> getSignedAvatarUrl(String storagePath) async =>
      throw const FurFeelDataException('No avatar in Demo mode.');
  @override
  Future<UserSettings> fetchMySettings() async => _settings;
  @override
  Future<void> saveMySettings(UserSettings settings) async {
    _settings = settings; // theme/unit switches work in the demo, in memory
  }

  @override
  Future<void> changePassword(String newPassword) async =>
      throw const FurFeelDataException('No password in Demo mode.');
  @override
  Future<void> deleteAccount() async =>
      throw const FurFeelDataException('Nothing to delete — Demo mode has no account.');

  @override
  Unsubscribe subscribeToDog(
    String dogId, {
    void Function(TelemetryReading reading)? onReading,
    void Function(StressClassification classification)? onClassification,
    void Function(Alert alert)? onAlert,
    void Function()? onVetNote,
  }) {
    return () async {}; // static sample data — nothing streams
  }
}
