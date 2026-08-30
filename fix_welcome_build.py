import re

with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'r') as f:
    content = f.read()

# Remove DemoRepository import
content = content.replace("import 'package:furfeel_mobile/data/demo_repository.dart';\n", "")
# Remove BrandPhotoFrame import (if we don't need it)
content = content.replace("import 'package:furfeel_mobile/widgets/brand_photo_frame.dart';\n", "")

# Rewrite WelcomePage
new_welcome_page = """class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.client});

  final SupabaseClient client;

  Future<String?> _signIn(String email, String password) async {
    try {
      await client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        try {
          await client.auth.resend(type: OtpType.signup, email: email);
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

  Future<String?> _signInWithGoogle() async {
    try {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'io.furfeel.app://login-callback',
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        queryParams: {'prompt': 'select_account'},
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not start Google sign-in. Check your connection and try again.';
    }
  }

  void _openLogin(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => LoginPage(
        signIn: _signIn,
        onGoogleSignIn: _signInWithGoogle,
        onCreateAccount: () => _openSignUp(context, replace: true),
      ),
    );
    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }

  void _openSignUp(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => SignUpPage(
        client: client,
        onGoogleSignIn: _signInWithGoogle,
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
          .animate(delay: Duration(milliseconds: 120 * index))
          .fadeIn(duration: 500.ms, curve: Curves.easeOut)
          .slideY(begin: 0.05, end: 0, duration: 500.ms, curve: Curves.easeOut);
    }

    return Scaffold(
      backgroundColor: context.ff.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space6),
          child: Column(
            children: [
              const Spacer(flex: 3),
              staggered(
                Image.asset(
                  'assets/photos/app_logo.png',
                  width: 140,
                  height: 140,
                ),
                0,
              ),
              const SizedBox(height: FurFeelTokens.space5),
              staggered(
                Image.asset(
                  'assets/photos/logo_title.png',
                  height: 40,
                ),
                1,
              ),
              const SizedBox(height: FurFeelTokens.space3),
              staggered(
                Text(
                  'Know how your dog is feeling, at home\\nor with your clinic, in real time.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: context.ff.inkMuted,
                    height: 1.4,
                  ),
                ),
                2,
              ),
              const Spacer(flex: 4),
              staggered(
                ElevatedButton(
                  onPressed: () => _openSignUp(context),
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
                3,
              ),
              const SizedBox(height: FurFeelTokens.space3),
              staggered(
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.ff.brandInk,
                    minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
                    side: BorderSide(color: context.ff.hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                    ),
                  ),
                  onPressed: () => _openLogin(context),
                  child: const Text(
                    'Log In',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
                4,
              ),
              const SizedBox(height: FurFeelTokens.space6),
            ],
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

