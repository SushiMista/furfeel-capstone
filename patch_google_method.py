import re

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'r') as f:
    content = f.read()

# 1. Add import for kIsWeb if missing
if "import 'package:flutter/foundation.dart' show kIsWeb;" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/foundation.dart' show kIsWeb;\nimport 'package:flutter/material.dart';")

# 2. Add _signInWithGoogle method
google_method = """  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      await widget.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'io.furfeel.app://login-callback',
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        queryParams: {'prompt': 'select_account'},
      );
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _busy = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not start Google sign-in. Check your connection.'; _busy = false; });
    }
  }

  Future<void> _createAccount() async {"""

content = content.replace("  Future<void> _createAccount() async {", google_method)

with open('apps/mobile/lib/screens/auth/progressive_signup_page.dart', 'w') as f:
    f.write(content)
