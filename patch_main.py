import re

with open('apps/mobile/lib/main.dart', 'r') as f:
    content = f.read()

# 1. Remove _onboardingSeenKey and _onboardingSeen
content = re.sub(r"  static const _onboardingSeenKey = 'furfeel_onboarding_seen_v1';\n", "", content)
content = re.sub(r"  bool\? _onboardingSeen;\n", "", content)

# 2. Update _bootstrap
bootstrap_old = """  Future<void> _bootstrap() async {
    final prefs = SharedPreferences.getInstance();
    await Future.wait([
      prefs,
      Future<void>.delayed(_minSplash),
    ]);
    final seen = (await prefs).getBool(_onboardingSeenKey) ?? false;
    if (!mounted) return;
    setState(() {
      _onboardingSeen = seen;
      _splashDone = true;
    });
  }"""
bootstrap_new = """  Future<void> _bootstrap() async {
    await Future<void>.delayed(_minSplash);
    if (!mounted) return;
    setState(() {
      _splashDone = true;
    });
  }"""
content = content.replace(bootstrap_old, bootstrap_new)

# 3. Remove _completeOnboarding
complete_onboarding = """  Future<void> _completeOnboarding() async {
    setState(() => _onboardingSeen = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }"""
content = content.replace(complete_onboarding, "")

# 4. Update the router in build()
router_old = """            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: !_splashDone || _onboardingSeen == null
                ? const SplashPage()
                : StreamBuilder<AuthState>(
                    stream: _client.auth.onAuthStateChange,
                    builder: (context, snapshot) {
                      final session = _client.auth.currentSession;
                      if (session == null) {
                        if (!_onboardingSeen!) {
                          return OnboardingPage(onDone: _completeOnboarding);
                        }
                        return WelcomePage(client: _client);
                      }
                      // A real network wait, unlike the cold-start beat, so
                      // this one earns a loader.
                      if (!_settings.loaded) return const SplashPage.loading();
                      return RootShell(
                        repository: _repository,
                        userEmail: session.user.email,
                        onSignOut: () => _client.auth.signOut(),
                      );
                    },
                  ),
            ),"""
router_new = """            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: !_splashDone
                ? const SplashPage()
                : StreamBuilder<AuthState>(
                    stream: _client.auth.onAuthStateChange,
                    builder: (context, snapshot) {
                      final session = _client.auth.currentSession;
                      if (session == null) {
                        return WelcomePage(client: _client);
                      }
                      // A real network wait, unlike the cold-start beat, so
                      // this one earns a loader.
                      if (!_settings.loaded) return const SplashPage.loading();
                      return RootShell(
                        repository: _repository,
                        userEmail: session.user.email,
                        onSignOut: () => _client.auth.signOut(),
                      );
                    },
                  ),
            ),"""
content = content.replace(router_old, router_new)

# 5. Remove onboarding_page import
content = re.sub(r"import 'package:furfeel_mobile/screens/onboarding_page\.dart';\n", "", content)

with open('apps/mobile/lib/main.dart', 'w') as f:
    f.write(content)
