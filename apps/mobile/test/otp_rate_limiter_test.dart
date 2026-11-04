import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:furfeel_mobile/util/otp_rate_limiter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('records attempts up to max attempts and triggers lockout', () async {
    const email = 'user@example.com';

    // Verify initial state
    expect(await OtpRateLimiter.getAttemptCount(email), 0);
    expect(await OtpRateLimiter.getLockoutRemainingSeconds(email), 0);

    // Record 9 attempts
    for (int i = 1; i <= 9; i++) {
      final res = await OtpRateLimiter.recordAttempt(email);
      expect(res.attempts, i);
      expect(res.isLockedOut, false);
      expect(res.lockoutSeconds, 0);
    }

    // 10th attempt should trigger 30-minute lockout
    final res10 = await OtpRateLimiter.recordAttempt(email);
    expect(res10.attempts, 10);
    expect(res10.isLockedOut, true);
    expect(res10.lockoutSeconds, 1800);

    final remaining = await OtpRateLimiter.getLockoutRemainingSeconds(email);
    expect(remaining, greaterThan(1700));
    expect(remaining, lessThanOrEqualTo(1800));
  });

  test('reset clears attempts and lockout', () async {
    const email = 'reset@example.com';

    await OtpRateLimiter.recordAttempt(email);
    expect(await OtpRateLimiter.getAttemptCount(email), 1);

    await OtpRateLimiter.reset(email);
    expect(await OtpRateLimiter.getAttemptCount(email), 0);
    expect(await OtpRateLimiter.getLockoutRemainingSeconds(email), 0);
  });
}

