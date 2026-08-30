import re

with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'r') as f:
    content = f.read()

# Add missing imports if needed
if 'auth_pattern_background.dart' not in content:
    content = content.replace("import 'package:furfeel_mobile/widgets/auth_form.dart';", "import 'package:furfeel_mobile/widgets/auth_form.dart';\nimport 'package:furfeel_mobile/widgets/auth_pattern_background.dart';")

new_welcome_page = """class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _googleBusy = false;

  Future<String?> _signIn(String email, String password) async {
    try {
      await widget.client.auth.signInWithPassword(email: email, password: password);
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
        onGoogleSignIn: () async { await _signInWithGoogle(); return null; },
        onCreateAccount: () => _openSignUp(context, replace: true),
      ),
    );
    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  void _openSignUp(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => SignUpPage(
        client: widget.client,
        onGoogleSignIn: () async { await _signInWithGoogle(); return null; },
        onSignIn: () => _openLogin(context, replace: true),
      ),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space5),
            child: Column(
              children: [
                const Spacer(flex: 3),
                staggered(
                  const Center(child: FurFeelLogo.auth(size: 200, animate: true)),
                  0,
                ),
                const SizedBox(height: FurFeelTokens.space5),
                staggered(
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space3),
                    child: Text(
                      'Know how your dog is feeling, at home or\\nwith your clinic, in real time.',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: context.ff.inkMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  1,
                ),
                const Spacer(flex: 2),
                staggered(
                  ElevatedButton(
                    onPressed: _googleBusy ? null : () => _openSignUp(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.ff.brand,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
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
                      backgroundColor: context.ff.brand.withValues(alpha: 0.05),
                      foregroundColor: context.ff.brandInk,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
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
                const Spacer(flex: 2),
                staggered(
                  Padding(
                    padding: const EdgeInsets.only(bottom: FurFeelTokens.space4),
                    child: Text(
                      'Decision support for you and your care team, never a\\ndiagnosis.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: context.ff.hairline,
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
"""

start_str = "class WelcomePage extends StatelessWidget {"
end_str = "class SignUpPage extends StatefulWidget {"

start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx != -1 and end_idx != -1:
    new_content = content[:start_idx] + new_welcome_page + content[end_idx:]
    with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'w') as f:
        f.write(new_content)
    print("Successfully updated WelcomePage!")
else:
    print("Could not find start or end block.")

