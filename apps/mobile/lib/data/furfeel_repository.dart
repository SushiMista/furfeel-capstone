import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'audit_service.dart';

/// Cancels the Realtime subscription created by [FurFeelRepository.subscribeToDog].
typedef Unsubscribe = Future<void> Function();

/// Thrown by pairing/profile operations with a message safe to show the owner.
class FurFeelDataException implements Exception {
  const FurFeelDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Data access for the owner app. All queries go through the anon-key Supabase
/// client and rely entirely on RLS to scope rows to the signed-in owner
/// (dogs.owner_user_id = auth.uid()) — no service key, no client-side filtering
/// standing in for policy.
abstract class FurFeelRepository {
  Future<Dog?> fetchFirstDog();

  /// All of the signed-in owner's dogs (docs/04: multi-dog profiles).
  Future<List<Dog>> fetchDogs();
  Future<Dog> createDog(DogDraft draft);
  Future<Dog> updateDog(String dogId, DogDraft draft);

  /// Deleting a dog with monitoring history fails (FKs protect raw telemetry —
  /// ADR-003); callers surface that as "history is preserved".
  Future<void> deleteDog(String dogId);

  /// Uploads a profile photo to the private media bucket and stores its path.
  Future<Dog> setDogPhoto(String dogId, Uint8List bytes, String fileExtension);

  /// Short-lived signed URL for an object in the private `media` bucket.
  Future<String> getSignedMediaUrl(String storagePath);

  Future<List<Clinic>> fetchClinics();

  Future<TelemetryReading?> fetchLatestReading(String dogId);
  Future<StressClassification?> fetchLatestClassification(String dogId);
  Future<List<TelemetryReading>> fetchRecentReadings(String dogId, {int limit = 20});

  /// Readings inside a date range, oldest-first, for the detailed log charts
  /// and exports. Capped at [limit] most-recent rows in the range.
  Future<List<TelemetryReading>> fetchReadingsBetween(
    String dogId,
    DateTime from,
    DateTime to, {
    int limit = 1000,
  });
  Future<List<StressClassification>> fetchRecentClassifications(String dogId, {int limit = 50});

  /// Classifications inside a date range, oldest-first (detailed log + report).
  Future<List<StressClassification>> fetchClassificationsBetween(
    String dogId,
    DateTime from,
    DateTime to, {
    int limit = 2000,
  });
  Future<List<Alert>> fetchAlerts(String dogId, {int limit = 20});

  /// Server-aggregated stress mix per local day (stress_daily_summary RPC) —
  /// powers the Trends tab without shipping raw telemetry to the phone.
  Future<List<DailyStressSummary>> fetchDailyStressSummary(String dogId, {int days = 14});

  /// Stress mix per local hour of day (stress_hourly_pattern RPC).
  Future<List<HourlyStressBucket>> fetchHourlyStressPattern(String dogId, {int days = 14});

  /// Acknowledge flow (docs/11 lifecycle step 4). Returns the updated alert, or
  /// null if it was no longer open (someone else acknowledged it first). RLS
  /// enforces acknowledged_by = the caller's own auth.uid().
  Future<Alert?> acknowledgeAlert(String alertId);

  // ---- Device pairing (docs/04 module 6) ----
  Future<Device?> fetchDeviceForDog(String dogId);
  Future<Device> pairDevice(String deviceCode, String dogId);
  Future<void> unpairDevice(String deviceId);

  /// Submit a bug report directly to the admin system.
  Future<void> submitBugReport({
    required String reporterName,
    required String reporterEmail,
    required String title,
    required String description,
    String category = 'bug',
  });

  /// Resting reference values for the vital detail screens (QA); null when
  /// the clinic hasn't set them.
  Future<DogBaseline?> fetchBaseline(String dogId);

  // ---- Vet Review, owner side (docs/04 module 5) ----
  Future<List<VetNote>> fetchVetNotes(String dogId, {int limit = 50});

  /// Vet notes with the author's name + avatar for the Home feed (QA:
  /// clinician comments surface without navigating). vet_note_feed RPC.
  Future<List<VetNoteFeedItem>> fetchVetNoteFeed(String dogId, {int limit = 20});
  Future<List<StressLabelEntry>> fetchStressLabels(String dogId, {int limit = 50});

  /// Guidance rows visible to this owner: global defaults plus any clinic
  /// overrides RLS lets them see (docs/04 Care Insights).
  Future<List<CareGuidance>> fetchCareGuidance();

  /// Daily wellness snapshot (dog_wellness_score RPC) — provisional
  /// engineering score, null when the day has no classifications.
  Future<WellnessSnapshot?> fetchWellness(String dogId, DateTime day);

  /// Everything the multi-dog Home card needs for one dog, in one call.
  Future<DogOverview> fetchDogOverview(Dog dog);

  // ---- Vet conversation, one per dog (ADR-026). Supplementary only. ----
  Future<List<DogMessageThread>> fetchDogMessageThreads();
  Future<List<DogMessage>> fetchDogMessages(String dogId);
  Future<void> sendDogMessage({
    required String dogId,
    String? body,
    Uint8List? mediaBytes,
    String? mediaExtension,
    String? mediaType, // 'image' | 'video'
    String? alertId,
    String? readingId,
  });

  /// Own messages only: RLS rejects anyone else's (dog_messages_*_author).
  Future<void> updateDogMessage(String messageId, String body);
  Future<void> deleteDogMessage(DogMessage message);
  Future<void> markDogMessagesRead(String dogId);
  Unsubscribe subscribeToDogMessages(String dogId, void Function() onChange);

  /// Signed-in user, to tell own messages from the clinic's.
  String? get currentUserId;

  // ---- Data-collection consent (docs/12) ----
  Future<bool> hasAcceptedConsent(String policyVersion);
  Future<void> acceptConsent(String policyVersion);

  // ---- Earlier observation submissions, kept for the data export. ----
  Future<List<MediaSubmission>> fetchMediaSubmissions(String dogId, {int limit = 50});

  /// Registers/refreshes a push token for the signed-in user (docs/04
  /// notifications). Delivery wiring (FCM/APNs credentials) is server-side.
  Future<void> registerPushToken(String platform, String token);

  // ---- Account & settings (docs/04 Account, Settings & Personalization) ----
  Future<UserProfile> fetchMyProfile();
  Future<UserProfile> updateMyName(String name);

  /// Contact fields (docs/04 Profile). Blank saves as null ("Not set").
  Future<UserProfile> updateMyPhone(String? phone);
  Future<UserProfile> updateMyEmergencyContact(String? contact);

  /// Uploads a profile photo to the private avatars bucket and stores its path.
  Future<UserProfile> setMyAvatar(Uint8List bytes, String fileExtension);

  /// Short-lived signed URL for an object in the private `avatars` bucket.
  Future<String> getSignedAvatarUrl(String storagePath);

  Future<UserSettings> fetchMySettings();
  Future<void> saveMySettings(UserSettings settings);

  Future<void> changePassword(String newPassword);

  /// Deletes the account via the delete-account Edge Function (auth deletion
  /// needs the service role). Fails with a friendly message when the account's
  /// dogs already have monitoring history (ADR-003: raw telemetry is kept).
  Future<void> deleteAccount();

  Unsubscribe subscribeToDog(
    String dogId, {
    void Function(TelemetryReading reading)? onReading,
    void Function(StressClassification classification)? onClassification,
    void Function(Alert alert)? onAlert,
    // QA: a new clinician note pops onto Home live. The realtime row lacks
    // author identity, so callers refetch the feed on this signal.
    void Function()? onVetNote,
  });
}

/// Per-dog snapshot for the multi-dog Home cards (photo/name come from [dog]).
class DogOverview {
  const DogOverview({
    required this.dog,
    this.reading,
    this.classification,
    this.device,
    this.wellness,
    this.openAlertsCount = 0,
  });

  final Dog dog;
  final TelemetryReading? reading;
  final StressClassification? classification;
  final Device? device;
  final WellnessSnapshot? wellness;
  final int openAlertsCount;
}

class SupabaseFurFeelRepository implements FurFeelRepository {
  SupabaseFurFeelRepository(this._client);

  final SupabaseClient _client;

  static const _readingColumns =
      'id, dog_id, captured_at, heart_rate_bpm, '
      'respiratory_rate_bpm, motion_activity, posture, '
      'ambient_temperature_c, humidity_percent, battery_percent';
  static const _classificationColumns =
      'id, dog_id, stress_level, score, model_version, reasons, created_at';
  static const _alertColumns =
      'id, dog_id, severity, type, message, status, acknowledged_by, acknowledged_at, created_at';

  @override
  Future<Dog?> fetchFirstDog() async {
    final rows = await _client.from('dogs').select().order('name', ascending: true).limit(1);
    if (rows.isEmpty) return null;
    return Dog.fromMap(rows.first);
  }

  @override
  Future<List<Dog>> fetchDogs() async {
    final rows = await _client.from('dogs').select().order('name', ascending: true);
    return rows.map(Dog.fromMap).toList();
  }

  @override
  Future<Dog> createDog(DogDraft draft) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const FurFeelDataException('You need to be signed in.');
    final row = await _client.from('dogs').insert(draft.toInsertMap(userId)).select().single();
    final dog = Dog.fromMap(row);
    AuditService.logEvent(
      action: 'pet.create',
      targetResource: 'dogs',
      targetId: dog.id,
      clinicId: dog.clinicId,
      details: {'name': dog.name, 'breed': dog.breed},
    );
    return dog;
  }

  @override
  Future<Dog> updateDog(String dogId, DogDraft draft) async {
    final row =
        await _client.from('dogs').update(draft.toUpdateMap()).eq('id', dogId).select().single();
    final dog = Dog.fromMap(row);
    AuditService.logEvent(
      action: 'pet.update',
      targetResource: 'dogs',
      targetId: dog.id,
      clinicId: dog.clinicId,
      details: {'name': dog.name, 'breed': dog.breed},
    );
    return dog;
  }

  @override
  Future<void> deleteDog(String dogId) async {
    try {
      await _client.from('dogs').delete().eq('id', dogId);
      AuditService.logEvent(
        action: 'pet.delete',
        targetResource: 'dogs',
        targetId: dogId,
        severity: 'warning',
      );
    } on PostgrestException catch (e) {
      // 23503 = foreign key violation: the dog already has monitoring history,
      // which is intentionally preserved (ADR-003: never delete raw telemetry).
      if (e.code == '23503') {
        throw const FurFeelDataException(
          "This dog already has monitoring history, which FurFeel keeps for the "
          'clinic record — the profile can\'t be deleted. You can unpair the '
          'harness instead.',
        );
      }
      rethrow;
    }
  }

  /// Storage failures come back as terse HTTP errors; surface the real reason
  /// instead of a misleading "check your connection" (QA: uploads failed
  /// silently while the network was fine).
  Future<void> _upload(String bucket, String path, Uint8List bytes,
      {bool upsert = false}) async {
    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: upsert),
          );
    } on StorageException catch (e) {
      throw FurFeelDataException('Upload failed: ${e.message}');
    }
  }

  @override
  Future<Dog> setDogPhoto(String dogId, Uint8List bytes, String fileExtension) async {
    final path = 'dogs/$dogId/profile.$fileExtension';
    await _upload('media', path, bytes, upsert: true);
    final row =
        await _client.from('dogs').update({'photo_path': path}).eq('id', dogId).select().single();
    return Dog.fromMap(row);
  }

  @override
  Future<String> getSignedMediaUrl(String storagePath) =>
      _client.storage.from('media').createSignedUrl(storagePath, 3600);

  @override
  Future<List<Clinic>> fetchClinics() async {
    final rows =
        await _client.from('clinics').select('id, name, address, contact_number').order('name');
    return rows.map(Clinic.fromMap).toList();
  }

  @override
  Future<TelemetryReading?> fetchLatestReading(String dogId) async {
    final rows = await _client
        .from('telemetry_readings')
        .select(_readingColumns)
        .eq('dog_id', dogId)
        .order('captured_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return TelemetryReading.fromMap(rows.first);
  }

  @override
  Future<StressClassification?> fetchLatestClassification(String dogId) async {
    final rows = await _client
        .from('stress_classifications')
        .select(_classificationColumns)
        .eq('dog_id', dogId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return StressClassification.fromMap(rows.first);
  }

  @override
  Future<List<TelemetryReading>> fetchRecentReadings(String dogId, {int limit = 20}) async {
    final rows = await _client
        .from('telemetry_readings')
        .select(_readingColumns)
        .eq('dog_id', dogId)
        .order('captured_at', ascending: false)
        .limit(limit);
    return rows.map(TelemetryReading.fromMap).toList();
  }

  @override
  Future<List<TelemetryReading>> fetchReadingsBetween(
    String dogId,
    DateTime from,
    DateTime to, {
    int limit = 1000,
  }) async {
    final rows = await _client
        .from('telemetry_readings')
        .select(_readingColumns)
        .eq('dog_id', dogId)
        .gte('captured_at', from.toUtc().toIso8601String())
        .lte('captured_at', to.toUtc().toIso8601String())
        .order('captured_at', ascending: false)
        .limit(limit);
    return rows.map(TelemetryReading.fromMap).toList().reversed.toList();
  }

  @override
  Future<List<StressClassification>> fetchRecentClassifications(String dogId,
      {int limit = 50}) async {
    final rows = await _client
        .from('stress_classifications')
        .select(_classificationColumns)
        .eq('dog_id', dogId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(StressClassification.fromMap).toList();
  }

  @override
  Future<List<StressClassification>> fetchClassificationsBetween(
    String dogId,
    DateTime from,
    DateTime to, {
    int limit = 2000,
  }) async {
    final rows = await _client
        .from('stress_classifications')
        .select(_classificationColumns)
        .eq('dog_id', dogId)
        .gte('created_at', from.toUtc().toIso8601String())
        .lte('created_at', to.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(StressClassification.fromMap).toList().reversed.toList();
  }

  @override
  Future<Alert?> acknowledgeAlert(String alertId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    // The status filter makes this a no-op if the alert was already handled.
    final rows = await _client
        .from('alerts')
        .update({
          'status': 'acknowledged',
          'acknowledged_by': userId,
          'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', alertId)
        .eq('status', 'open')
        .select(_alertColumns);
    if (rows.isEmpty) return null;
    return Alert.fromMap(rows.first);
  }

  @override
  Future<List<Alert>> fetchAlerts(String dogId, {int limit = 20}) async {
    final rows = await _client
        .from('alerts')
        .select(_alertColumns)
        .eq('dog_id', dogId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Alert.fromMap).toList();
  }

  @override
  Future<List<DailyStressSummary>> fetchDailyStressSummary(String dogId, {int days = 14}) async {
    final rows = await _client.rpc(
      'stress_daily_summary',
      params: {
        'p_dog_id': dogId,
        'p_days': days,
        'p_tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      },
    ) as List;
    return rows
        .map((r) => DailyStressSummary.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<List<HourlyStressBucket>> fetchHourlyStressPattern(String dogId, {int days = 14}) async {
    final rows = await _client.rpc(
      'stress_hourly_pattern',
      params: {
        'p_dog_id': dogId,
        'p_days': days,
        'p_tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      },
    ) as List;
    return rows
        .map((r) => HourlyStressBucket.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  static const _deviceColumns =
      'id, dog_id, device_code, status, last_seen_at, firmware_version, battery_percent';

  @override
  Future<Device?> fetchDeviceForDog(String dogId) async {
    final rows =
        await _client.from('devices').select(_deviceColumns).eq('dog_id', dogId).limit(1);
    if (rows.isEmpty) return null;
    return Device.fromMap(rows.first);
  }

  @override
  Future<Device> pairDevice(String deviceCode, String dogId) async {
    try {
      final data = await _client.rpc(
        'pair_device',
        params: {'p_device_code': deviceCode, 'p_dog_id': dogId},
      );
      // PostgREST returns a single object for `returns devices`; tolerate a
      // one-element array in case of representation changes.
      final row = data is List ? data.first : data;
      final device = Device.fromMap(Map<String, dynamic>.from(row as Map));
      AuditService.logEvent(
        action: 'device.pair',
        targetResource: 'devices',
        targetId: device.id,
        details: {'device_code': deviceCode, 'dog_id': dogId},
      );
      return device;
    } on PostgrestException catch (e) {
      throw FurFeelDataException(switch (e.message) {
        'DEVICE_NOT_FOUND' =>
          'No harness with that code — double-check the code printed on the device.',
        'DEVICE_ALREADY_PAIRED' => 'That harness is already paired with another dog.',
        'DOG_NOT_OWNED' => 'That dog isn\'t on your account.',
        _ => 'Pairing failed — please try again.',
      });
    }
  }

  @override
  Future<void> unpairDevice(String deviceId) async {
    try {
      await _client.rpc('unpair_device', params: {'p_device_id': deviceId});
      AuditService.logEvent(
        action: 'device.unpair',
        targetResource: 'devices',
        targetId: deviceId,
        severity: 'warning',
      );
    } on PostgrestException catch (e) {
      throw FurFeelDataException(
        e.message == 'DEVICE_NOT_OWNED'
            ? 'That harness isn\'t paired with one of your dogs.'
            : 'Unpairing failed — please try again.',
      );
    }
  }

  @override
  Future<DogBaseline?> fetchBaseline(String dogId) async {
    final rows = await _client
        .from('dog_baselines')
        .select('resting_heart_rate_bpm, resting_respiratory_rate_bpm')
        .eq('dog_id', dogId)
        .limit(1);
    if (rows.isEmpty) return null;
    return DogBaseline.fromMap(rows.first);
  }

  @override
  Future<List<VetNoteFeedItem>> fetchVetNoteFeed(String dogId, {int limit = 20}) async {
    final rows = await _client.rpc(
      'vet_note_feed',
      params: {'p_dog_id': dogId, 'p_limit': limit},
    ) as List;
    return rows
        .map((r) => VetNoteFeedItem.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<List<VetNote>> fetchVetNotes(String dogId, {int limit = 50}) async {
    final rows = await _client
        .from('vet_notes')
        .select('id, dog_id, note, created_at, author:users(name)')
        .eq('dog_id', dogId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(VetNote.fromMap).toList();
  }

  @override
  Future<List<StressLabelEntry>> fetchStressLabels(String dogId, {int limit = 50}) async {
    final rows = await _client
        .from('stress_labels')
        .select('id, dog_id, confirmed_level, agreed_with_model, note, created_at, '
            'vet:users!stress_labels_vet_user_id_fkey(name)')
        .eq('dog_id', dogId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(StressLabelEntry.fromMap).toList();
  }

  @override
  Future<List<CareGuidance>> fetchCareGuidance() async {
    // RLS already limits rows to global defaults + clinics this owner can see.
    final rows = await _client
        .from('care_guidance')
        .select('stress_level, context_key, clinic_id, title, body');
    return rows.map(CareGuidance.fromMap).toList();
  }

  @override
  Future<WellnessSnapshot?> fetchWellness(String dogId, DateTime day) async {
    final rows = await _client.rpc(
      'dog_wellness_score',
      params: {
        'p_dog_id': dogId,
        'p_day':
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      },
    ) as List;
    if (rows.isEmpty) return null;
    return WellnessSnapshot.fromMap(Map<String, dynamic>.from(rows.first as Map));
  }

  @override
  Future<DogOverview> fetchDogOverview(Dog dog) async {
    final results = await Future.wait<Object?>([
      fetchLatestReading(dog.id),
      fetchLatestClassification(dog.id),
      fetchDeviceForDog(dog.id),
      // Wellness is a nicety on the card — never let it fail the overview.
      fetchWellness(dog.id, DateTime.now()).catchError((_) => null),
      fetchAlerts(dog.id).catchError((_) => <Alert>[]),
    ]);
    return DogOverview(
      dog: dog,
      reading: results[0] as TelemetryReading?,
      classification: results[1] as StressClassification?,
      device: results[2] as Device?,
      wellness: results[3] as WellnessSnapshot?,
      openAlertsCount: (results[4] as List<Alert>).where((a) => a.status == 'open').length,
    );
  }

  @override
  Future<bool> hasAcceptedConsent(String policyVersion) async {
    final rows = await _client
        .from('consents')
        .select('id')
        .eq('user_id', _requiredUserId)
        .eq('policy_version', policyVersion)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<void> acceptConsent(String policyVersion) async {
    await _client.from('consents').upsert(
      {'user_id': _requiredUserId, 'policy_version': policyVersion},
      onConflict: 'user_id,policy_version',
      ignoreDuplicates: true,
    );
  }

  static const _mediaColumns =
      'id, dog_id, storage_path, media_type, note, reviewed_at, review_note, created_at, '
      'submitter:users!media_submissions_submitted_by_user_id_fkey(name, avatar_path), '
      'reviewer:users!media_submissions_reviewed_by_user_id_fkey(name, avatar_path)';

  static const _dogMessageColumns =
      'id, dog_id, author_user_id, body, media_path, media_type, edited_at, created_at, '
      'author:users!dog_messages_author_user_id_fkey(name, avatar_path), '
      'alert:alerts(type), '
      'reading:telemetry_readings(heart_rate_bpm, ambient_temperature_c, captured_at)';

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<DogMessageThread>> fetchDogMessageThreads() async {
    final rows = await _client.rpc('dog_message_threads') as List<dynamic>;
    return rows
        .map((r) => DogMessageThread.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<DogMessage>> fetchDogMessages(String dogId) async {
    final rows = await _client
        .from('dog_messages')
        .select(_dogMessageColumns)
        .eq('dog_id', dogId)
        .order('created_at', ascending: true);
    return rows.map(DogMessage.fromMap).toList();
  }

  @override
  Future<void> sendDogMessage({
    required String dogId,
    String? body,
    Uint8List? mediaBytes,
    String? mediaExtension,
    String? mediaType,
    String? alertId,
    String? readingId,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw const FurFeelDataException('You need to be signed in.');
    String? mediaPath;
    if (mediaBytes != null) {
      final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
      mediaPath = 'dogs/$dogId/chat-$stamp.$mediaExtension';
      await _upload('media', mediaPath, mediaBytes);
    }
    final trimmed = body?.trim();
    await _client.from('dog_messages').insert({
      'dog_id': dogId,
      'author_user_id': userId,
      'body': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'media_path': mediaPath,
      'media_type': mediaPath == null ? null : mediaType,
      'alert_id': alertId,
      'telemetry_reading_id': readingId,
    });
    if (mediaPath != null) {
      AuditService.logEvent(
        action: 'media.submit',
        targetResource: 'dog_messages',
        details: {'dog_id': dogId, 'media_type': mediaType},
      );
    }
  }

  @override
  Future<void> updateDogMessage(String messageId, String body) async {
    await _client
        .from('dog_messages')
        .update({
          'body': body.trim(),
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId);
  }

  @override
  Future<void> deleteDogMessage(DogMessage message) async {
    // The row is what people see, so it goes first. Removing the file after is
    // best-effort: a leftover blob isn't worth surfacing a failed delete.
    await _client.from('dog_messages').delete().eq('id', message.id);
    final path = message.mediaPath;
    if (path == null) return;
    try {
      await _client.storage.from('media').remove([path]);
    } catch (_) {}
  }

  @override
  Future<void> markDogMessagesRead(String dogId) async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client.from('dog_message_reads').upsert({
      'dog_id': dogId,
      'user_id': userId,
      'last_read_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'dog_id,user_id');
  }

  @override
  Unsubscribe subscribeToDogMessages(String dogId, void Function() onChange) {
    final channel = _client.channel('dog-messages-$dogId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dog_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'dog_id',
          value: dogId,
        ),
        callback: (_) => onChange(),
      )
      ..subscribe();
    return () => _client.removeChannel(channel);
  }

  @override
  Future<List<MediaSubmission>> fetchMediaSubmissions(String dogId, {int limit = 50}) async {
    final rows = await _client
        .from('media_submissions')
        .select(_mediaColumns)
        .eq('dog_id', dogId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(MediaSubmission.fromMap).toList();
  }

  @override
  Future<void> registerPushToken(String platform, String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('push_tokens').upsert(
      {
        'user_id': userId,
        'platform': platform,
        'token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  static const _profileColumns =
      'id, name, email, created_at, avatar_path, phone, emergency_contact';

  String get _requiredUserId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const FurFeelDataException('You need to be signed in.');
    return userId;
  }

  @override
  Future<UserProfile> fetchMyProfile() async {
    final row = await _client
        .from('users')
        .select(_profileColumns)
        .eq('id', _requiredUserId)
        .single();
    return UserProfile.fromMap(row);
  }

  @override
  Future<UserProfile> updateMyName(String name) async {
    final row = await _client
        .from('users')
        .update({'name': name.trim()})
        .eq('id', _requiredUserId)
        .select(_profileColumns)
        .single();
    return UserProfile.fromMap(row);
  }

  Future<UserProfile> _updateMyField(String column, String? value) async {
    final trimmed = value?.trim();
    final row = await _client
        .from('users')
        .update({column: (trimmed == null || trimmed.isEmpty) ? null : trimmed})
        .eq('id', _requiredUserId)
        .select(_profileColumns)
        .single();
    return UserProfile.fromMap(row);
  }

  @override
  Future<UserProfile> updateMyPhone(String? phone) => _updateMyField('phone', phone);

  @override
  Future<UserProfile> updateMyEmergencyContact(String? contact) =>
      _updateMyField('emergency_contact', contact);

  @override
  Future<UserProfile> setMyAvatar(Uint8List bytes, String fileExtension) async {
    final userId = _requiredUserId;
    final path = '$userId/avatar.$fileExtension';
    await _upload('avatars', path, bytes, upsert: true);
    final row = await _client
        .from('users')
        .update({'avatar_path': path})
        .eq('id', userId)
        .select(_profileColumns)
        .single();
    return UserProfile.fromMap(row);
  }

  @override
  Future<String> getSignedAvatarUrl(String storagePath) =>
      _client.storage.from('avatars').createSignedUrl(storagePath, 3600);

  @override
  Future<UserSettings> fetchMySettings() async {
    // The signup trigger creates the row; tolerate its absence for accounts
    // that predate it by falling back to defaults.
    final rows =
        await _client.from('user_settings').select().eq('user_id', _requiredUserId).limit(1);
    if (rows.isEmpty) return const UserSettings();
    return UserSettings.fromMap(rows.first);
  }

  @override
  Future<void> saveMySettings(UserSettings settings) async {
    await _client.from('user_settings').upsert({
      'user_id': _requiredUserId,
      ...settings.toUpdateMap(),
    });
  }

  @override
  Future<void> changePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw FurFeelDataException(e.message);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account');
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw FurFeelDataException(
        message ?? 'Could not delete the account — please try again.',
      );
    }
  }

  @override
  Unsubscribe subscribeToDog(
    String dogId, {
    void Function(TelemetryReading reading)? onReading,
    void Function(StressClassification classification)? onClassification,
    void Function(Alert alert)? onAlert,
    void Function()? onVetNote,
  }) {
    // Single-dog screen: safe to filter Realtime by dog_id directly (docs/10).
    final channel = _client.channel('owner-dog-$dogId');

    void listen(String table, void Function(Map<String, dynamic> row) handle) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'dog_id',
          value: dogId,
        ),
        callback: (payload) => handle(payload.newRecord),
      );
    }

    if (onReading != null) {
      listen('telemetry_readings', (row) => onReading(TelemetryReading.fromMap(row)));
    }
    if (onClassification != null) {
      listen('stress_classifications', (row) => onClassification(StressClassification.fromMap(row)));
    }
    if (onAlert != null) {
      listen('alerts', (row) => onAlert(Alert.fromMap(row)));
    }
    if (onVetNote != null) {
      listen('vet_notes', (row) => onVetNote());
    }

    channel.subscribe();
    return () => _client.removeChannel(channel);
  }

  @override
  Future<void> submitBugReport({
    required String reporterName,
    required String reporterEmail,
    required String title,
    required String description,
    String category = 'bug',
  }) async {
    await _client.from('bug_reports').insert({
      'reporter_name': reporterName,
      'reporter_email': reporterEmail,
      'title': title,
      'description': description,
      'category': category,
      'user_id': _client.auth.currentUser?.id,
    });
  }
}
