/// Dart mirrors of the canonical row shapes in `packages/shared/types/*.ts`
/// (docs/09 Database Schema). Keep field names and nullability in sync with
/// those TypeScript definitions — they are the single source of truth.
library;

enum StressLevel {
  calm,
  mild,
  moderate,
  high;

  static StressLevel fromName(String name) =>
      StressLevel.values.firstWhere((l) => l.name == name, orElse: () => StressLevel.calm);

  /// Encouraging, non-clinical phrasing per docs/19 ("Biscuit is calm right now").
  String phrase(String dogName) => switch (this) {
        StressLevel.calm => '$dogName is calm right now',
        StressLevel.mild => '$dogName is a little uneasy',
        StressLevel.moderate => '$dogName could use some comfort',
        StressLevel.high => '$dogName needs your attention',
      };
}

double? _toDouble(Object? v) => v == null ? null : (v as num).toDouble();
int? _toInt(Object? v) => v == null ? null : (v as num).round();

class Dog {
  const Dog({
    required this.id,
    required this.ownerUserId,
    required this.name,
    this.clinicId,
    this.breed,
    this.birthdate,
    this.sex,
    this.weightKg,
    this.notes,
    this.photoPath,
  });

  final String id;
  final String ownerUserId;
  final String? clinicId;
  final String name;
  final String? breed;
  final String? birthdate;
  final String? sex;
  final double? weightKg;
  final String? notes;

  /// Path in the private `media` storage bucket (resolved via signed URL).
  final String? photoPath;

  factory Dog.fromMap(Map<String, dynamic> map) => Dog(
        id: map['id'] as String,
        ownerUserId: map['owner_user_id'] as String,
        clinicId: map['clinic_id'] as String?,
        name: map['name'] as String,
        breed: map['breed'] as String?,
        birthdate: map['birthdate'] as String?,
        sex: map['sex'] as String?,
        weightKg: _toDouble(map['weight_kg']),
        notes: map['notes'] as String?,
        photoPath: map['photo_path'] as String?,
      );

  /// True on the dog's birthday (month + day match); false without a
  /// parsable birthdate. Drives the Home birthday moment.
  bool isBirthday(DateTime now) {
    final raw = birthdate;
    if (raw == null) return false;
    final born = DateTime.tryParse(raw);
    if (born == null) return false;
    return born.month == now.month && born.day == now.day;
  }

  /// Age in whole years derived from [birthdate] (docs/09 prefers birthdate
  /// over free-text age); null when the birthdate is unknown or unparsable.
  int? get ageYears {
    final raw = birthdate;
    if (raw == null) return null;
    final born = DateTime.tryParse(raw);
    if (born == null) return null;
    final now = DateTime.now();
    var years = now.year - born.year;
    if (now.month < born.month || (now.month == born.month && now.day < born.day)) {
      years -= 1;
    }
    return years < 0 ? null : years;
  }
}

class Clinic {
  const Clinic({required this.id, required this.name, this.address});

  final String id;
  final String name;
  final String? address;

  factory Clinic.fromMap(Map<String, dynamic> map) => Clinic(
        id: map['id'] as String,
        name: map['name'] as String,
        address: map['address'] as String?,
      );
}

class Device {
  const Device({
    required this.id,
    required this.deviceCode,
    required this.status,
    this.dogId,
    this.lastSeenAt,
    this.firmwareVersion,
    this.batteryPercent,
  });

  final String id;
  final String? dogId;
  final String deviceCode;
  final String status; // active | inactive | offline | maintenance
  final DateTime? lastSeenAt;
  final String? firmwareVersion;

  /// Latest reported battery 0-100, mirrored from telemetry by the intake
  /// function; null until the harness first reports it.
  final int? batteryPercent;

  bool get isOnline => status == 'active';

  /// Matches the provisional low-battery alert threshold
  /// (classifier_config.json device_alerts.low_battery_percent = 15).
  bool get isBatteryLow => batteryPercent != null && batteryPercent! <= 15;

  factory Device.fromMap(Map<String, dynamic> map) => Device(
        id: map['id'] as String,
        dogId: map['dog_id'] as String?,
        deviceCode: map['device_code'] as String,
        status: map['status'] as String,
        lastSeenAt: map['last_seen_at'] == null
            ? null
            : DateTime.parse(map['last_seen_at'] as String).toLocal(),
        firmwareVersion: map['firmware_version'] as String?,
        batteryPercent: _toInt(map['battery_percent']),
      );
}

class VetNote {
  const VetNote({
    required this.id,
    required this.dogId,
    required this.note,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String dogId;
  final String note;
  final DateTime createdAt;
  final String? authorName;

  factory VetNote.fromMap(Map<String, dynamic> map) => VetNote(
        id: map['id'] as String,
        dogId: map['dog_id'] as String,
        note: map['note'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        authorName: (map['author'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

/// Vet-confirmed stress assessment (stress_labels): what the owner sees on the
/// Vet Review screen as the clinic's confirmed read of their dog.
class StressLabelEntry {
  const StressLabelEntry({
    required this.id,
    required this.dogId,
    required this.confirmedLevel,
    required this.createdAt,
    this.agreedWithModel,
    this.note,
    this.vetName,
  });

  final String id;
  final String dogId;
  final StressLevel confirmedLevel;
  final DateTime createdAt;
  final bool? agreedWithModel;
  final String? note;
  final String? vetName;

  factory StressLabelEntry.fromMap(Map<String, dynamic> map) => StressLabelEntry(
        id: map['id'] as String,
        dogId: map['dog_id'] as String,
        confirmedLevel: StressLevel.fromName(map['confirmed_level'] as String),
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        agreedWithModel: map['agreed_with_model'] as bool?,
        note: map['note'] as String?,
        vetName: (map['vet'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

/// Vet-authored guidance (care_guidance). Informational only — never
/// diagnosis (docs/04 Care Insights). Keyed either by [stressLevel] (per-level
/// default) or by [contextKey] (a COMBINATION of signals, e.g. 'cold_stressed',
/// 'restless_high_hr'); context rows win when their combination is active.
class CareGuidance {
  const CareGuidance({
    required this.title,
    required this.body,
    this.stressLevel,
    this.contextKey,
    this.clinicId,
  });

  final StressLevel? stressLevel;
  final String? contextKey;
  final String title;
  final String body;
  final String? clinicId;

  factory CareGuidance.fromMap(Map<String, dynamic> map) => CareGuidance(
        stressLevel: map['stress_level'] == null
            ? null
            : StressLevel.fromName(map['stress_level'] as String),
        contextKey: map['context_key'] as String?,
        title: map['title'] as String,
        body: map['body'] as String,
        clinicId: map['clinic_id'] as String?,
      );
}

/// One message in a media-submission conversation (media_messages): the owner
/// and the clinic replying back and forth under a submitted photo/video.
class MediaMessage {
  const MediaMessage({
    required this.id,
    required this.mediaSubmissionId,
    required this.authorUserId,
    required this.body,
    required this.createdAt,
    this.authorName,
    this.authorAvatarPath,
  });

  final String id;
  final String mediaSubmissionId;
  final String authorUserId;
  final String body;
  final DateTime createdAt;
  final String? authorName;
  final String? authorAvatarPath;

  factory MediaMessage.fromMap(Map<String, dynamic> map) => MediaMessage(
        id: map['id'] as String,
        mediaSubmissionId: map['media_submission_id'] as String,
        authorUserId: map['author_user_id'] as String,
        body: map['body'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        authorName: (map['author'] as Map<String, dynamic>?)?['name'] as String?,
        authorAvatarPath: (map['author'] as Map<String, dynamic>?)?['avatar_path'] as String?,
      );
}

/// Daily wellness snapshot (dog_wellness_score RPC). PROVISIONAL engineering
/// score, not clinical — see docs/08.
class WellnessSnapshot {
  const WellnessSnapshot({
    required this.score,
    required this.calmPercent,
    required this.activePercent,
    required this.restPercent,
    required this.alertCount,
    required this.sampleCount,
  });

  final int score; // 0-100
  final double calmPercent;
  final double activePercent;
  final double restPercent;
  final int alertCount;
  final int sampleCount;

  factory WellnessSnapshot.fromMap(Map<String, dynamic> map) => WellnessSnapshot(
        score: (map['score'] as num).toInt(),
        calmPercent: _toDouble(map['calm_percent']) ?? 0,
        activePercent: _toDouble(map['active_percent']) ?? 0,
        restPercent: _toDouble(map['rest_percent']) ?? 0,
        alertCount: (map['alert_count'] as num?)?.toInt() ?? 0,
        sampleCount: (map['sample_count'] as num?)?.toInt() ?? 0,
      );
}

/// Owner observation submission (media_submissions). Supplementary context for
/// the clinic — NEVER a classifier input (ADR-010).
class MediaSubmission {
  const MediaSubmission({
    required this.id,
    required this.dogId,
    required this.storagePath,
    required this.mediaType,
    required this.createdAt,
    this.note,
    this.reviewedAt,
    this.reviewNote,
    this.submitterName,
    this.submitterAvatarPath,
    this.reviewerName,
    this.reviewerAvatarPath,
  });

  final String id;
  final String dogId;
  final String storagePath;
  final String mediaType; // image | video
  final DateTime createdAt;
  final String? note;
  final DateTime? reviewedAt;
  final String? reviewNote;

  /// Sender identity for the thread's opening bubble (docs/04 module 5:
  /// chat-style profiles) — the owner who submitted this observation.
  final String? submitterName;
  final String? submitterAvatarPath;

  /// Sender identity for the review bubble — the clinician who reviewed it.
  final String? reviewerName;
  final String? reviewerAvatarPath;

  bool get isReviewed => reviewedAt != null;

  factory MediaSubmission.fromMap(Map<String, dynamic> map) => MediaSubmission(
        id: map['id'] as String,
        dogId: map['dog_id'] as String,
        storagePath: map['storage_path'] as String,
        mediaType: map['media_type'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        note: map['note'] as String?,
        reviewedAt: map['reviewed_at'] == null
            ? null
            : DateTime.parse(map['reviewed_at'] as String).toLocal(),
        reviewNote: map['review_note'] as String?,
        submitterName: (map['submitter'] as Map<String, dynamic>?)?['name'] as String?,
        submitterAvatarPath:
            (map['submitter'] as Map<String, dynamic>?)?['avatar_path'] as String?,
        reviewerName: (map['reviewer'] as Map<String, dynamic>?)?['name'] as String?,
        reviewerAvatarPath:
            (map['reviewer'] as Map<String, dynamic>?)?['avatar_path'] as String?,
      );
}

/// One local day's stress-level mix (stress_daily_summary RPC) + avg motion.
class DailyStressSummary {
  const DailyStressSummary({
    required this.day,
    required this.calm,
    required this.mild,
    required this.moderate,
    required this.high,
    this.avgMotion,
  });

  final DateTime day; // date only, local
  final int calm;
  final int mild;
  final int moderate;
  final int high;
  final double? avgMotion;

  int get total => calm + mild + moderate + high;

  /// Share of classifications that were calm (null when the day has no data).
  double? get calmShare => total == 0 ? null : calm / total;

  factory DailyStressSummary.fromMap(Map<String, dynamic> map) => DailyStressSummary(
        day: DateTime.parse(map['day'] as String),
        calm: (map['calm'] as num?)?.toInt() ?? 0,
        mild: (map['mild'] as num?)?.toInt() ?? 0,
        moderate: (map['moderate'] as num?)?.toInt() ?? 0,
        high: (map['high'] as num?)?.toInt() ?? 0,
        avgMotion: _toDouble(map['avg_motion']),
      );
}

/// Stress mix for one local hour of day, pooled over the window
/// (stress_hourly_pattern RPC).
class HourlyStressBucket {
  const HourlyStressBucket({
    required this.hour,
    required this.calm,
    required this.mild,
    required this.moderate,
    required this.high,
  });

  final int hour; // 0-23, local
  final int calm;
  final int mild;
  final int moderate;
  final int high;

  int get total => calm + mild + moderate + high;
  double? get calmShare => total == 0 ? null : calm / total;

  factory HourlyStressBucket.fromMap(Map<String, dynamic> map) => HourlyStressBucket(
        hour: (map['hour'] as num).toInt(),
        calm: (map['calm'] as num?)?.toInt() ?? 0,
        mild: (map['mild'] as num?)?.toInt() ?? 0,
        moderate: (map['moderate'] as num?)?.toInt() ?? 0,
        high: (map['high'] as num?)?.toInt() ?? 0,
      );
}

/// Draft for creating/updating a dog profile (docs/04 Pet Creation).
class DogDraft {
  const DogDraft({
    required this.name,
    this.breed,
    this.birthdate,
    this.sex,
    this.weightKg,
    this.notes,
    this.clinicId,
  });

  final String name;
  final String? breed;
  final String? birthdate;
  final String? sex;
  final double? weightKg;
  final String? notes;
  final String? clinicId;

  Map<String, dynamic> toInsertMap(String ownerUserId) => {
        'owner_user_id': ownerUserId,
        ...toUpdateMap(),
      };

  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'breed': breed,
        'birthdate': birthdate,
        'sex': sex,
        'weight_kg': weightKg,
        'notes': notes,
        'clinic_id': clinicId,
      };
}

class TelemetryReading {
  const TelemetryReading({
    required this.id,
    required this.dogId,
    required this.capturedAt,
    this.heartRateBpm,
    this.bodyTemperatureC,
    this.respiratoryRateBpm,
    this.motionActivity,
    this.posture,
    this.ambientTemperatureC,
    this.humidityPercent,
    this.batteryPercent,
  });

  final String id;
  final String dogId;
  final DateTime capturedAt;
  final int? heartRateBpm;
  final double? bodyTemperatureC;
  final int? respiratoryRateBpm;
  final double? motionActivity;
  final String? posture;

  /// Environment context (drives combination care insights: hot/cold + state).
  final double? ambientTemperatureC;
  final double? humidityPercent;

  /// Device health only — never a classifier input (docs/07).
  final int? batteryPercent;

  factory TelemetryReading.fromMap(Map<String, dynamic> map) => TelemetryReading(
        id: map['id'] as String,
        dogId: map['dog_id'] as String,
        capturedAt: DateTime.parse(map['captured_at'] as String).toLocal(),
        heartRateBpm: _toInt(map['heart_rate_bpm']),
        bodyTemperatureC: _toDouble(map['body_temperature_c']),
        respiratoryRateBpm: _toInt(map['respiratory_rate_bpm']),
        motionActivity: _toDouble(map['motion_activity']),
        posture: map['posture'] as String?,
        ambientTemperatureC: _toDouble(map['ambient_temperature_c']),
        humidityPercent: _toDouble(map['humidity_percent']),
        batteryPercent: _toInt(map['battery_percent']),
      );
}

class StressClassification {
  const StressClassification({
    required this.id,
    required this.dogId,
    required this.stressLevel,
    required this.createdAt,
    this.score,
    this.modelVersion,
    this.reasons = const [],
  });

  final String id;
  final String dogId;
  final StressLevel stressLevel;
  final DateTime createdAt;
  final double? score;
  final String? modelVersion;

  /// Which rules/context fired (stress_classifications.reasons jsonb) — feeds
  /// the owner-facing "why" and combination care insights.
  final List<String> reasons;

  factory StressClassification.fromMap(Map<String, dynamic> map) => StressClassification(
        id: map['id'] as String,
        dogId: map['dog_id'] as String,
        stressLevel: StressLevel.fromName(map['stress_level'] as String),
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        score: _toDouble(map['score']),
        modelVersion: map['model_version'] as String?,
        reasons: (map['reasons'] as List?)?.cast<String>() ?? const [],
      );
}

class Alert {
  const Alert({
    required this.id,
    required this.dogId,
    required this.severity,
    required this.type,
    required this.message,
    required this.status,
    required this.createdAt,
    this.acknowledgedBy,
    this.acknowledgedAt,
  });

  final String id;
  final String dogId;
  final String severity; // info | warning | critical
  final String type;
  final String message;
  final String status; // open | acknowledged | resolved
  final DateTime createdAt;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;

  bool get isOpen => status == 'open';

  factory Alert.fromMap(Map<String, dynamic> map) => Alert(
        id: map['id'] as String,
        dogId: map['dog_id'] as String,
        severity: map['severity'] as String,
        type: map['type'] as String,
        message: map['message'] as String,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        acknowledgedBy: map['acknowledged_by'] as String?,
        acknowledgedAt: map['acknowledged_at'] == null
            ? null
            : DateTime.parse(map['acknowledged_at'] as String).toLocal(),
      );
}

/// ADDED: mirror of public.users for the signed-in account (docs/09).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarPath,
    this.phone,
    this.emergencyContact,
  });

  final String id;
  final String name;
  final String email;

  /// Path in the private `avatars` bucket (resolved via signed URL).
  final String? avatarPath;

  final String? phone;

  /// Free text ("name and number") — who the clinic reaches if the owner can't be.
  final String? emergencyContact;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        avatarPath: map['avatar_path'] as String?,
        phone: map['phone'] as String?,
        emergencyContact: map['emergency_contact'] as String?,
      );

  /// First name for greetings ("Good morning, Joshua").
  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

/// ADDED: per-user preferences row (docs/09 user_settings). One row per user;
/// created by the signup trigger, so fetch can assume it exists.
class UserSettings {
  const UserSettings({
    this.theme = 'light',
    this.temperatureUnit = 'c',
    this.notificationsEnabled = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.mutedAlertTypes = const [],
  });

  /// 'system' | 'light' | 'dark'
  final String theme;

  /// 'c' | 'f'
  final String temperatureUnit;
  final bool notificationsEnabled;

  /// "HH:MM:SS" as Postgres `time` renders it; null = no quiet hours.
  final String? quietHoursStart;
  final String? quietHoursEnd;

  /// Alert `type` values the user muted (QA: per-type notification management).
  final List<String> mutedAlertTypes;

  factory UserSettings.fromMap(Map<String, dynamic> map) => UserSettings(
        theme: map['theme'] as String? ?? 'light',
        temperatureUnit: map['temperature_unit'] as String? ?? 'c',
        notificationsEnabled: map['notifications_enabled'] as bool? ?? true,
        quietHoursStart: map['quiet_hours_start'] as String?,
        quietHoursEnd: map['quiet_hours_end'] as String?,
        mutedAlertTypes: (map['muted_alert_types'] as List?)?.cast<String>() ?? const [],
      );

  UserSettings copyWith({
    String? theme,
    String? temperatureUnit,
    bool? notificationsEnabled,
    Object? quietHoursStart = _unset,
    Object? quietHoursEnd = _unset,
    List<String>? mutedAlertTypes,
  }) =>
      UserSettings(
        theme: theme ?? this.theme,
        temperatureUnit: temperatureUnit ?? this.temperatureUnit,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        quietHoursStart: quietHoursStart == _unset
            ? this.quietHoursStart
            : quietHoursStart as String?,
        quietHoursEnd:
            quietHoursEnd == _unset ? this.quietHoursEnd : quietHoursEnd as String?,
        mutedAlertTypes: mutedAlertTypes ?? this.mutedAlertTypes,
      );

  static const _unset = Object();

  Map<String, dynamic> toUpdateMap() => {
        'theme': theme,
        'temperature_unit': temperatureUnit,
        'notifications_enabled': notificationsEnabled,
        'quiet_hours_start': quietHoursStart,
        'quiet_hours_end': quietHoursEnd,
        'muted_alert_types': mutedAlertTypes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

/// ADDED (QA): per-dog resting reference values (docs/09 dog_baselines) shown
/// on the vital detail screens; classifier falls back to global defaults.
class DogBaseline {
  const DogBaseline({
    this.restingHeartRateBpm,
    this.restingRespiratoryRateBpm,
    this.normalBodyTemperatureC,
  });

  final int? restingHeartRateBpm;
  final int? restingRespiratoryRateBpm;
  final double? normalBodyTemperatureC;

  factory DogBaseline.fromMap(Map<String, dynamic> map) => DogBaseline(
        restingHeartRateBpm: _toInt(map['resting_heart_rate_bpm']),
        restingRespiratoryRateBpm: _toInt(map['resting_respiratory_rate_bpm']),
        normalBodyTemperatureC: _toDouble(map['normal_body_temperature_c']),
      );
}

/// ADDED (QA): vet note with author identity for the owner Home feed
/// (vet_note_feed RPC — name + avatar only).
class VetNoteFeedItem {
  const VetNoteFeedItem({
    required this.id,
    required this.note,
    required this.createdAt,
    required this.authorName,
    this.authorAvatarPath,
  });

  final String id;
  final String note;
  final DateTime createdAt;
  final String authorName;
  final String? authorAvatarPath;

  factory VetNoteFeedItem.fromMap(Map<String, dynamic> map) => VetNoteFeedItem(
        id: map['id'] as String,
        note: map['note'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        authorName: map['author_name'] as String? ?? 'Your care team',
        authorAvatarPath: map['author_avatar_path'] as String?,
      );
}
