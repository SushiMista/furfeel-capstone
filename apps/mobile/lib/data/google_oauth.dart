import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

const nativeGoogleOAuthRedirectUrl = 'io.furfeel.app://login-callback';
const mobileWebGoogleOAuthRedirectUrl = 'http://localhost:5175/';
const _mobileWebAuthRedirectUrl = String.fromEnvironment(
  'MOBILE_WEB_AUTH_REDIRECT_URL',
);
const _dashboardWebOrigins = {
  'https://furfeel.site',
  'https://www.furfeel.site',
};

bool _isDashboardUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return _dashboardWebOrigins.contains(url);
  }
  return _dashboardWebOrigins.contains('${uri.scheme}://${uri.host}');
}

String authRedirectUrl({
  bool isWeb = kIsWeb,
  String currentOrigin = '',
  String configuredWebRedirectUrl = _mobileWebAuthRedirectUrl,
}) {
  if (!isWeb) return nativeGoogleOAuthRedirectUrl;

  final configured = configuredWebRedirectUrl.trim();
  if (configured.isNotEmpty && !_isDashboardUrl(configured)) return configured;

  String origin = currentOrigin.trim();
  if (origin.isEmpty && isWeb) {
    try {
      if (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') {
        origin = Uri.base.origin;
      }
    } catch (_) {
      // Ignore if Uri.base is not http/https
    }
  }
  if (origin.isEmpty) {
    origin = mobileWebGoogleOAuthRedirectUrl;
  }
  return _isDashboardUrl(origin) ? mobileWebGoogleOAuthRedirectUrl : origin;
}

String googleOAuthRedirectUrl({
  bool isWeb = kIsWeb,
  String currentOrigin = '',
  String configuredWebRedirectUrl = _mobileWebAuthRedirectUrl,
}) {
  return authRedirectUrl(
    isWeb: isWeb,
    currentOrigin: currentOrigin,
    configuredWebRedirectUrl: configuredWebRedirectUrl,
  );
}

Future<void> startGoogleOAuth(SupabaseClient client) {
  return client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: authRedirectUrl(),
    authScreenLaunchMode: kIsWeb
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication,
    queryParams: {'prompt': 'select_account'},
  );
}

