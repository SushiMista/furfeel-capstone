import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/data/google_oauth.dart';

void main() {
  test('native Google OAuth returns to the app deep link', () {
    expect(googleOAuthRedirectUrl(isWeb: false), nativeGoogleOAuthRedirectUrl);
  });

  test(
    'web Google OAuth can be pinned away from the dashboard login route',
    () {
      expect(
        googleOAuthRedirectUrl(
          isWeb: true,
          currentOrigin: 'https://www.furfeel.site',
          configuredWebRedirectUrl: 'http://localhost:5175/',
        ),
        'http://localhost:5175/',
      );
    },
  );

  test('web Google OAuth falls back to the current origin for local dev', () {
    expect(
      googleOAuthRedirectUrl(
        isWeb: true,
        currentOrigin: 'http://localhost:5175',
      ),
      'http://localhost:5175',
    );
  });

  test('web Google OAuth never returns to the dashboard origin', () {
    expect(
      googleOAuthRedirectUrl(
        isWeb: true,
        currentOrigin: 'https://furfeel.site',
      ),
      mobileWebGoogleOAuthRedirectUrl,
    );
  });

  test('web Google OAuth ignores dashboard redirect config', () {
    expect(
      googleOAuthRedirectUrl(
        isWeb: true,
        currentOrigin: 'http://localhost:5175',
        configuredWebRedirectUrl: 'https://furfeel.site/login',
      ),
      'http://localhost:5175',
    );
  });
}
