import re

with open('apps/mobile/lib/main.dart', 'r') as f:
    content = f.read()

# Add global flag to FurFeelApp
if 'static bool isProgressiveOnboarding = false;' not in content:
    content = content.replace("class FurFeelApp extends StatefulWidget {", "class FurFeelApp extends StatefulWidget {\n  const FurFeelApp({super.key});\n  static bool isProgressiveOnboarding = false;\n\n  @override\n  State<FurFeelApp> createState() => _FurFeelAppState();\n}\n\nclass _OldFurFeelApp {}")
    # clean up the dummy class
    content = content.replace("class _OldFurFeelApp {}", "")
    # wait, FurFeelApp already has a const constructor.
    # Let's just use regex to insert the flag.

with open('apps/mobile/lib/main.dart', 'r') as f:
    content = f.read()

import re
content = re.sub(r'class FurFeelApp extends StatefulWidget {\n  const FurFeelApp\(\{super\.key\}\);\n', 'class FurFeelApp extends StatefulWidget {\n  const FurFeelApp({super.key});\n  static bool isProgressiveOnboarding = false;\n', content)

# update signedIn event
old_signed_in = """      if (state.event == AuthChangeEvent.signedIn) {
        _settings.load();
        // OAuth sign-ins (e.g. Google) land via this stream while a pushed
        // auth screen may still sit on top of the home StreamBuilder -- pop
        // back so the freshly signed-in shell is actually visible.
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }"""
new_signed_in = """      if (state.event == AuthChangeEvent.signedIn) {
        _settings.load();
        if (!FurFeelApp.isProgressiveOnboarding) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      }"""
content = content.replace(old_signed_in, new_signed_in)

with open('apps/mobile/lib/main.dart', 'w') as f:
    f.write(content)
