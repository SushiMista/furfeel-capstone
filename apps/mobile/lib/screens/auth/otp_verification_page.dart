import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:furfeel_mobile/data/google_oauth.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/util/otp_rate_limiter.dart';
import 'package:furfeel_mobile/widgets/auth_form.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    super.key,
    required this.client,
    required this.email,
  });

  final SupabaseClient client;
  final String email;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _code = TextEditingController();
  String? _error;
  bool _submitting = false;

  Timer? _resendTimer;
  int _cooldownSeconds = 0;
  int _lockoutSeconds = 0;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _checkInitialLockout();
  }

  @override
  void dispose() {
    _code.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkInitialLockout() async {
    final remaining = await OtpRateLimiter.getLockoutRemainingSeconds(widget.email);
    final count = await OtpRateLimiter.getAttemptCount(widget.email);
    if (!mounted) return;
    setState(() {
      _lockoutSeconds = remaining;
      _attempts = count;
    });

    if (remaining > 0) {
      _startLockoutCountdown(remaining);
    }
  }

  void _startLockoutCountdown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _lockoutSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSeconds > 0) {
        setState(() => _lockoutSeconds--);
      } else {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _attempts = 0;
        });
      }
    });
  }

  void _startCooldown([int seconds = OtpRateLimiter.defaultCooldownSeconds]) {
    setState(() => _cooldownSeconds = seconds);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatLockoutTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  Future<void> _submit() async {
    final token = _code.text.trim();
    if (token.length < 6) {
      setState(() => _error = 'Please enter the 6-digit code.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response = await widget.client.auth.verifyOTP(
        type: OtpType.signup,
        token: token,
        email: widget.email,
      );
      if (!mounted) return;
      if (response.session != null) {
        await OtpRateLimiter.reset(widget.email);
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not verify code. Please try again.';
      });
    }
  }

  Future<void> _resendCode() async {
    if (_lockoutSeconds > 0) {
      setState(() {
        _error =
            'Too many requests. Please try again in ${_formatLockoutTime(_lockoutSeconds)}.';
      });
      return;
    }

    if (_cooldownSeconds > 0) return;

    final result = await OtpRateLimiter.recordAttempt(widget.email);
    if (!mounted) return;

    setState(() {
      _attempts = result.attempts;
      _error = null;
    });

    if (result.isLockedOut) {
      _startLockoutCountdown(result.lockoutSeconds);
      setState(() {
        _error =
            'Maximum resend attempts reached. Please try again in ${_formatLockoutTime(result.lockoutSeconds)}.';
      });
      return;
    }

    // Start 60-second cooldown
    _startCooldown(OtpRateLimiter.defaultCooldownSeconds);

    try {
      await widget.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
        emailRedirectTo: authRedirectUrl(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent!')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') || msg.contains('over_email_send_rate_limit')) {
        setState(() {
          _error = 'Email sending limit reached. Please wait before trying again.';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to resend code. Please try again later.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLockedOut = _lockoutSeconds > 0;
    final isCoolingDown = _cooldownSeconds > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: FurFeelTokens.space5,
                vertical: FurFeelTokens.space4,
              ),
              children: [
                const SizedBox(height: FurFeelTokens.space4),
                Center(
                  child: Image.asset(
                    'assets/photos/logo_title.png',
                    height: 56,
                  ),
                ),
                const SizedBox(height: FurFeelTokens.space5),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        context.ff.brand.withValues(alpha: 0.20),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: FurFeelTokens.space5),
                Text(
                  'Check your email',
                  style: textTheme.headlineSmall?.copyWith(
                    color: context.ff.brandInk,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ).entrance(context),
                const SizedBox(height: FurFeelTokens.space2),
                Text(
                  'We sent a 6-digit code to\n${widget.email}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.ff.inkMuted,
                  ),
                  textAlign: TextAlign.center,
                ).entrance(context, index: 1),
                const SizedBox(height: FurFeelTokens.space5),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    letterSpacing: 12,
                    fontWeight: FontWeight.w700,
                    color: context.ff.brandInk,
                  ),
                  onChanged: (val) {
                    if (val.length == 6) {
                      _submit();
                    }
                  },
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: textTheme.headlineMedium?.copyWith(
                      letterSpacing: 12,
                      fontWeight: FontWeight.w700,
                      color: context.ff.hairline,
                    ),
                    filled: true,
                    fillColor: context.ff.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        FurFeelTokens.radiusMd,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: FurFeelTokens.space4,
                    ),
                  ),
                ).entrance(context, index: 2),
                if (_error != null) ...[
                  const SizedBox(height: FurFeelTokens.space4),
                  InlineFormError(message: _error!),
                ],
                const SizedBox(height: FurFeelTokens.space5),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: context.ff.brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(
                      FurFeelTokens.touchTargetMin,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        FurFeelTokens.radiusSm,
                      ),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const BusyButtonLabel(label: 'Verifying')
                      : const Text('Verify code'),
                ).entrance(context, index: 3),
                const SizedBox(height: FurFeelTokens.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't get it?",
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.ff.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: (isLockedOut || isCoolingDown) ? null : _resendCode,
                      child: Text(
                        isLockedOut
                            ? 'Locked for ${_formatLockoutTime(_lockoutSeconds)}'
                            : isCoolingDown
                                ? 'Resend code in ${_cooldownSeconds}s'
                                : 'Resend code',
                      ),
                    ),
                  ],
                ).entrance(context, index: 4),
                if (_attempts > 0 && !isLockedOut) ...[
                  const SizedBox(height: FurFeelTokens.space1),
                  Text(
                    '${OtpRateLimiter.maxResendAttempts - _attempts} attempts remaining',
                    style: textTheme.bodySmall?.copyWith(
                      color: context.ff.inkMuted,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
