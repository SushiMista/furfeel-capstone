import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/auth_form.dart';
import 'package:furfeel_mobile/widgets/auth_pattern_background.dart';
import 'package:furfeel_mobile/screens/auth/progressive_signup_page.dart';
import 'package:furfeel_mobile/widgets/furfeel_logo.dart';
import 'package:furfeel_mobile/screens/auth/login_page.dart';
import 'package:furfeel_mobile/screens/auth/otp_verification_page.dart';
import 'package:furfeel_mobile/screens/home/root_shell.dart';

/// ADDED: real first-run flow (docs/04 Onboarding/sign-up): a warm animated
/// welcome, then create account (Supabase Auth) or sign in. After sign-up the
/// auth stream flips the app into RootShell, whose guided setup takes over
/// (add your dog → pair the harness → done).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _googleBusy = false;

  Future<String?> _signIn(String email, String password) async {
    try {
<<<<<<< HEAD
      final res = await client.auth.signInWithPassword(email: email, password: password);
      final user = res.user;
      if (user != null) {
        final userRow = await client.from('users').select('role').eq('id', user.id).maybeSingle();
        final role = userRow?['role'] as String?;
        if (role != null && role != 'owner') {
          await client.auth.signOut();
          return 'Access Denied: Clinic staff & admin accounts must log in via the FurFeel Web Dashboard.';
        }
      }
=======
      await widget.client.auth.signInWithPassword(email: email, password: password);
>>>>>>> joshua-app-updated
      return null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        try {
          await widget.client.auth.resend(type: OtpType.signup, email: email);
          return 'Email not verified. We sent a new code to your inbox.';
        } catch (_) {}
      }
      if (e.message.contains('SocketException') ||
          e.message.contains('Failed host lookup') ||
          e.message.contains('ClientException')) {
        return 'Unable to connect to FurFeel servers. Please check your connection and try again.';
      }
      return e.message;
    } catch (_) {
      return 'Could not sign in. Check your connection and try again.';
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _googleBusy = true);
    try {
      await widget.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'io.furfeel.app://login-callback',
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        queryParams: {'prompt': 'select_account'},
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start Google sign-in. Check your connection.')));
      }
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  void _openLogin(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => LoginPage(
        signIn: _signIn,
        onGoogleSignIn: () async { _signInWithGoogle(); return null; },
        onCreateAccount: () => _openSignUp(context, replace: true),
      ),
    );
    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  void _openSignUp(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => ProgressiveSignUpPage(client: widget.client),
    );
    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final reduce = context.reduceMotion;

    Widget staggered(Widget child, int index) {
      if (reduce) return child;
      return child
          .animate(delay: Duration(milliseconds: 100 * index))
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOut);
    }

    return Scaffold(
      backgroundColor: context.ff.surface,
      body: AuthPatternBackground(
        color: context.ff.hairline,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space5),
            child: Column(
              children: [
                const Spacer(),
                staggered(
                  Center(
                    child: Image.asset(
                      'assets/photos/logo_title.png',
                      width: 240,
                    ),
                  ),
                  0,
                ),
                const SizedBox(height: FurFeelTokens.space5),
                staggered(
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space3),
                    child: Text(
                      'Know how your dog is feeling, at home or\nwith your clinic, in real time.',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: context.ff.inkMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  1,
                ),
                const SizedBox(height: FurFeelTokens.space7),
                staggered(
                  ElevatedButton(
                    onPressed: _googleBusy ? null : () => _openSignUp(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.ff.brand,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                      ),
                    ),
                    child: const Text(
                      'Create account',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  2,
                ),
                const SizedBox(height: FurFeelTokens.space3),
                staggered(
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.ff.surfaceAlt,
                      foregroundColor: context.ff.ink,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                      ),
                    ),
                    onPressed: _googleBusy ? null : () => _openLogin(context),
                    child: const Text(
                      'I already have an account',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  3,
                ),
                const SizedBox(height: FurFeelTokens.space4),
                staggered(
                  const OrDivider(),
                  4,
                ),
                const SizedBox(height: FurFeelTokens.space4),
                staggered(
                  GoogleSignInButton(
                    busy: _googleBusy,
                    onPressed: _signInWithGoogle,
                  ),
                  5,
                ),
                const Spacer(),
                staggered(
                  Padding(
                    padding: const EdgeInsets.only(bottom: FurFeelTokens.space4),
                    child: Text(
                      'Decision support for you and your care team, never a\ndiagnosis.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: context.ff.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ),
                  6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
