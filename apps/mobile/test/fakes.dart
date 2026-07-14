import 'dart:typed_data';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/models/models.dart';

/// Configurable in-memory repository for widget tests — no Supabase client.
class FakeRepository implements FurFeelRepository {
  FakeRepository({
    List<Dog> dogs = const [],
    this.latestReading,
    this.latestClassification,
    this.recentReadings = const [],
    this.alerts = const [],
    this.device,
    this.guidance = const [],
    this.vetNotes = const [],
    this.stressLabels = const [],
    this.mediaSubmissions = const [],
    this.clinics = const [],
    this.dailySummaries = const [],
    this.hourlyPattern = const [],
  }) : dogs = List.of(dogs);

  List<Dog> dogs;
  TelemetryReading? latestReading;
  StressClassification? latestClassification;
  List<TelemetryReading> recentReadings;
  List<Alert> alerts;
  Device? device;
  List<CareGuidance> guidance;
  List<VetNote> vetNotes;
  List<StressLabelEntry> stressLabels;
  List<MediaSubmission> mediaSubmissions;
  List<Clinic> clinics;
  List<DailyStressSummary> dailySummaries;
  List<HourlyStressBucket> hourlyPattern;

  int subscribeCalls = 0;
  final acknowledgedIds = <String>[];
  final registeredPushTokens = <(String, String)>[];
  DogDraft? lastCreatedDraft;
  (String, DogDraft)? lastUpdated;
  (String, String)? lastPaired; // (code, dogId)
  String? lastUnpairedDeviceId;
  ({String dogId, String mediaType, String? note})? lastObservation;

  @override
  Future<Dog?> fetchFirstDog() async => dogs.isEmpty ? null : dogs.first;

  @override
  Future<List<Dog>> fetchDogs() async => List.of(dogs);

  @override
  Future<Dog> createDog(DogDraft draft) async {
    lastCreatedDraft = draft;
    final dog = Dog(
      id: 'dog-${dogs.length + 1}',
      ownerUserId: 'user-1',
      name: draft.name,
      breed: draft.breed,
      birthdate: draft.birthdate,
      sex: draft.sex,
      weightKg: draft.weightKg,
      notes: draft.notes,
      clinicId: draft.clinicId,
    );
    dogs = [...dogs, dog];
    return dog;
  }

  @override
  Future<Dog> updateDog(String dogId, DogDraft draft) async {
    lastUpdated = (dogId, draft);
    final existing = dogs.firstWhere((d) => d.id == dogId);
    final updated = Dog(
      id: existing.id,
      ownerUserId: existing.ownerUserId,
      name: draft.name,
      breed: draft.breed,
      birthdate: draft.birthdate,
      sex: draft.sex,
      weightKg: draft.weightKg,
      notes: draft.notes,
      clinicId: draft.clinicId,
      photoPath: existing.photoPath,
    );
    dogs = dogs.map((d) => d.id == dogId ? updated : d).toList();
    return updated;
  }

  @override
  Future<void> deleteDog(String dogId) async {
    dogs = dogs.where((d) => d.id != dogId).toList();
  }

  @override
  Future<Dog> setDogPhoto(String dogId, Uint8List bytes, String fileExtension) async =>
      dogs.firstWhere((d) => d.id == dogId);

  @override
  Future<String> getSignedMediaUrl(String storagePath) async =>
      'https://example.com/$storagePath';

  @override
  Future<List<Clinic>> fetchClinics() async => clinics;

  @override
  Future<TelemetryReading?> fetchLatestReading(String dogId) async => latestReading;

  @override
  Future<StressClassification?> fetchLatestClassification(String dogId) async =>
      latestClassification;

  @override
  Future<List<TelemetryReading>> fetchRecentReadings(String dogId, {int limit = 20}) async =>
      recentReadings;

  @override
  Future<List<StressClassification>> fetchRecentClassifications(String dogId,
          {int limit = 50}) async =>
      const [];

  @override
  Future<List<Alert>> fetchAlerts(String dogId, {int limit = 20}) async => alerts;

  @override
  Future<List<DailyStressSummary>> fetchDailyStressSummary(String dogId, {int days = 14}) async =>
      dailySummaries;

  @override
  Future<List<HourlyStressBucket>> fetchHourlyStressPattern(String dogId, {int days = 14}) async =>
      hourlyPattern;

  @override
  Future<Alert?> acknowledgeAlert(String alertId) async {
    acknowledgedIds.add(alertId);
    final original = alerts.firstWhere((a) => a.id == alertId);
    return Alert(
      id: original.id,
      dogId: original.dogId,
      severity: original.severity,
      type: original.type,
      message: original.message,
      status: 'acknowledged',
      createdAt: original.createdAt,
      acknowledgedBy: 'user-1',
      acknowledgedAt: DateTime.now(),
    );
  }

  @override
  Future<Device?> fetchDeviceForDog(String dogId) async => device;

  @override
  Future<Device> pairDevice(String deviceCode, String dogId) async {
    lastPaired = (deviceCode, dogId);
    final paired = Device(
      id: 'device-1',
      dogId: dogId,
      deviceCode: deviceCode,
      status: 'inactive',
    );
    device = paired;
    return paired;
  }

  @override
  Future<void> unpairDevice(String deviceId) async {
    lastUnpairedDeviceId = deviceId;
    device = null;
  }

  DogBaseline? baseline;
  List<VetNoteFeedItem> vetNoteFeed = const [];

  @override
  Future<DogBaseline?> fetchBaseline(String dogId) async => baseline;

  @override
  Future<List<VetNoteFeedItem>> fetchVetNoteFeed(String dogId, {int limit = 20}) async =>
      vetNoteFeed;

  @override
  Future<List<VetNote>> fetchVetNotes(String dogId, {int limit = 50}) async => vetNotes;

  @override
  Future<List<StressLabelEntry>> fetchStressLabels(String dogId, {int limit = 50}) async =>
      stressLabels;

  @override
  Future<List<CareGuidance>> fetchCareGuidance() async => guidance;

  @override
  Future<List<MediaSubmission>> fetchMediaSubmissions(String dogId, {int limit = 50}) async =>
      mediaSubmissions;

  @override
  Future<MediaSubmission> submitObservation({
    required String dogId,
    required Uint8List bytes,
    required String fileExtension,
    required String mediaType,
    String? note,
  }) async {
    lastObservation = (dogId: dogId, mediaType: mediaType, note: note);
    final submission = MediaSubmission(
      id: 'media-${mediaSubmissions.length + 1}',
      dogId: dogId,
      storagePath: 'dogs/$dogId/obs.$fileExtension',
      mediaType: mediaType,
      createdAt: DateTime.now(),
      note: note,
    );
    mediaSubmissions = [submission, ...mediaSubmissions];
    return submission;
  }

  @override
  Future<void> registerPushToken(String platform, String token) async {
    registeredPushTokens.add((platform, token));
  }

  // ---- Account & settings ----
  UserProfile profile =
      const UserProfile(id: 'user-1', name: 'Jamie Rivera', email: 'owner@example.com');
  UserSettings userSettings = const UserSettings();
  String? lastPassword;
  bool accountDeleted = false;

  @override
  Future<UserProfile> fetchMyProfile() async => profile;

  @override
  Future<UserProfile> updateMyName(String name) async {
    profile = UserProfile(
        id: profile.id, name: name, email: profile.email, avatarPath: profile.avatarPath);
    return profile;
  }

  @override
  Future<UserProfile> setMyAvatar(Uint8List bytes, String fileExtension) async {
    profile = UserProfile(
        id: profile.id,
        name: profile.name,
        email: profile.email,
        avatarPath: '${profile.id}/avatar.$fileExtension');
    return profile;
  }

  @override
  Future<String> getSignedAvatarUrl(String storagePath) async =>
      'https://example.com/signed/$storagePath';

  @override
  Future<UserSettings> fetchMySettings() async => userSettings;

  @override
  Future<void> saveMySettings(UserSettings settings) async {
    userSettings = settings;
  }

  @override
  Future<void> changePassword(String newPassword) async {
    lastPassword = newPassword;
  }

  @override
  Future<void> deleteAccount() async {
    accountDeleted = true;
  }

  @override
  Unsubscribe subscribeToDog(
    String dogId, {
    void Function(TelemetryReading reading)? onReading,
    void Function(StressClassification classification)? onClassification,
    void Function(Alert alert)? onAlert,
    void Function()? onVetNote,
  }) {
    subscribeCalls++;
    return () async {};
  }
}
