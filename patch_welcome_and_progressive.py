import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# Add import for FurFeelApp to set the flag
if 'import \'package:furfeel_mobile/main.dart\';' not in content:
    content = content.replace("import 'package:furfeel_mobile/theme/furfeel_tokens.dart';", "import 'package:furfeel_mobile/theme/furfeel_tokens.dart';\nimport 'package:furfeel_mobile/main.dart';")

# Set the flag in initState and dispose
init_dispose = """  @override
  void initState() {
    super.initState();
    FurFeelApp.isProgressiveOnboarding = true;
  }

  @override
  void dispose() {
    FurFeelApp.isProgressiveOnboarding = false;
    _pageController.dispose();"""

content = content.replace("  @override\n  void dispose() {\n    _pageController.dispose();", init_dispose)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)

# Now update WelcomePage
with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'r') as f:
    welcome_content = f.read()

# Replace SignUpPage import with ProgressiveSignUpPage
welcome_content = re.sub(r'class SignUpPage extends StatefulWidget \{[\s\S]*', '', welcome_content)
welcome_content = welcome_content.replace("import 'package:furfeel_mobile/widgets/auth_pattern_background.dart';", "import 'package:furfeel_mobile/widgets/auth_pattern_background.dart';\nimport 'package:furfeel_mobile/screens/auth/progressive_signup_page.dart';")

# Replace _openSignUp
old_open_signup = """  void _openSignUp(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => SignUpPage(
        client: widget.client,
        onGoogleSignIn: () async { _signInWithGoogle(); return null; },
        onSignIn: () => _openLogin(context, replace: true),
      ),
    );
    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }"""
new_open_signup = """  void _openSignUp(BuildContext context, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => ProgressiveSignUpPage(client: widget.client),
    );
    final navigator = Navigator.of(context);
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  }"""

welcome_content = welcome_content.replace(old_open_signup, new_open_signup)

with open('apps/mobile/lib/screens/auth/welcome_page.dart', 'w') as f:
    f.write(welcome_content)
