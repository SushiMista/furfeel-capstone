import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/furfeel_repository.dart';
import 'data/settings_controller.dart';
import 'pages/onboarding_page.dart';
import 'pages/root_shell.dart';
import 'pages/splash_page.dart';
import 'pages/welcome_page.dart';
import 'theme/furfeel_theme.dart';
import 'theme/furfeel_tokens.dart';

// Client credentials come in via --dart-define (see apps/mobile/README.md):
//   flutter run --dart-define-from-file=env.json
// Only the anon key is ever used here — RLS is the gate; the service role key
// must never ship in a client (CLAUDE.md).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  // publishableKey also accepts a legacy anon key; both are client-safe.
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseAnonKey);
  runApp(const FurFeelApp());
}

// ADDED: stateful root — owns the SettingsController so theme (system/light/
// dark) and temperature unit from user_settings apply app-wide, and reacts to
// OS brightness changes for the 'system' theme.
class FurFeelApp extends StatefulWidget {
  const FurFeelApp({super.key});

  @override
  State<FurFeelApp> createState() => _FurFeelAppState();
}

class _FurFeelAppState extends State<FurFeelApp> with WidgetsBindingObserver {
  static const _onboardingSeenKey = 'furfeel_onboarding_seen_v1';

  late final SupabaseClient _client = Supabase.instance.client;
  late final SupabaseFurFeelRepository _repository = SupabaseFurFeelRepository(_client);
  late final SettingsController _settings = SettingsController(_repository);

  // Cold-start gate: splash holds until the seen-flag is read AND the brand
  // beat has had a moment on screen, so the splash never just flickers.
  bool? _onboardingSeen;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_client.auth.currentSession != null) _settings.load();
    _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) _settings.load();
      if (state.event == AuthChangeEvent.signedOut) _settings.clear();
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = SharedPreferences.getInstance();
    await Future.wait([
      prefs,
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    final seen = (await prefs).getBool(_onboardingSeenKey) ?? false;
    if (!mounted) return;
    setState(() {
      _onboardingSeen = seen;
      _splashDone = true;
    });
  }

  Future<void> _completeOnboarding() async {
    setState(() => _onboardingSeen = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        final dark = _settings.resolveDark(
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
        );
        return SettingsScope(
          controller: _settings,
          child: MaterialApp(
            title: 'FurFeel',
            debugShowCheckedModeBanner: false,
            theme: buildFurFeelTheme(dark: dark),
            home: !_splashDone || _onboardingSeen == null
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
                      if (!_settings.loaded) return const SplashPage();
                      return RootShell(
                        repository: _repository,
                        userEmail: session.user.email,
                        onSignOut: () => _client.auth.signOut(),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FurFeel',
      theme: buildFurFeelTheme(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(FurFeelTokens.space5),
            child: Text(
              'Missing Supabase configuration.\n\n'
              'Run with:\nflutter run --dart-define-from-file=env.json\n\n'
              '(see apps/mobile/README.md)',
              textAlign: TextAlign.center,
              style: TextStyle(color: FurFeelTokens.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}
