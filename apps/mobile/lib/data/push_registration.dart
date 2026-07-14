import 'package:flutter/foundation.dart';

import 'furfeel_repository.dart';

/// Push-token registration (docs/04 Notifications).
///
/// The in-app side is complete: `push_tokens` (own-rows RLS) + the repository's
/// [FurFeelRepository.registerPushToken] upsert. What's intentionally left for
/// a human is the platform credential wiring — adding `firebase_messaging`
/// (with google-services.json / GoogleService-Info.plist) or an APNs setup,
/// then passing the real token into [registerPushTokenIfAvailable] via
/// [tokenProvider]. Until then this is a structured no-op, so the app runs
/// without any Firebase project configured.
Future<void> registerPushTokenIfAvailable(
  FurFeelRepository repository, {
  Future<String?> Function()? tokenProvider,
}) async {
  if (tokenProvider == null) return; // FCM/APNs not wired yet — see note above.
  try {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) return;
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'web',
    };
    await repository.registerPushToken(platform, token);
  } catch (_) {
    // Push registration must never break app startup.
  }
}
