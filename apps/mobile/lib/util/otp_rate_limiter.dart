import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to handle client-side rate-limiting and persistent lockouts for OTP requests.
///
/// Features:
/// - Cooldown period between resend clicks (default: 60s).
/// - Maximum attempts (default: 10).
/// - Lockout duration when max attempts exceeded (default: 30 minutes).
/// - Persisted across app restarts using SharedPreferences per email.
class OtpRateLimiter {
  static const int defaultCooldownSeconds = 60;
  static const int maxResendAttempts = 10;
  static const Duration lockoutDuration = Duration(minutes: 30);

  static String _keyAttempts(String email) =>
      'otp_attempts_${email.trim().toLowerCase()}';
  static String _keyLockout(String email) =>
      'otp_lockout_${email.trim().toLowerCase()}';

  /// Returns remaining lockout time in seconds if locked out, or 0 if not locked out.
  static Future<int> getLockoutRemainingSeconds(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutEpoch = prefs.getInt(_keyLockout(email));
    if (lockoutEpoch == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= lockoutEpoch) {
      // Lockout expired, clean up
      await prefs.remove(_keyLockout(email));
      await prefs.remove(_keyAttempts(email));
      return 0;
    }
    return max(0, ((lockoutEpoch - now) / 1000).ceil());
  }

  /// Returns the number of resend attempts recorded so far.
  static Future<int> getAttemptCount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAttempts(email)) ?? 0;
  }

  /// Records a new resend attempt.
  /// If attempts reach [maxResendAttempts], establishes a lockout for [lockoutDuration].
  /// Returns the updated attempt count and whether lockout is now triggered.
  static Future<({int attempts, bool isLockedOut, int lockoutSeconds})> recordAttempt(
    String email,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    int current = (prefs.getInt(_keyAttempts(email)) ?? 0) + 1;
    await prefs.setInt(_keyAttempts(email), current);

    if (current >= maxResendAttempts) {
      final lockoutUntil = DateTime.now().add(lockoutDuration).millisecondsSinceEpoch;
      await prefs.setInt(_keyLockout(email), lockoutUntil);
      return (
        attempts: current,
        isLockedOut: true,
        lockoutSeconds: lockoutDuration.inSeconds,
      );
    }

    return (
      attempts: current,
      isLockedOut: false,
      lockoutSeconds: 0,
    );
  }

  /// Clears rate limit state upon successful verification or reset.
  static Future<void> reset(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAttempts(email));
    await prefs.remove(_keyLockout(email));
  }
}

