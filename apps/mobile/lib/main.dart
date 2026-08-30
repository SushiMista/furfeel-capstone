import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/furfeel_repository.dart';
import 'data/settings_controller.dart';
import 'data/status_cache.dart';
import 'package:furfeel_mobile/screens/home/root_shell.dart';
import 'package:furfeel_mobile/screens/auth/splash_page.dart';
import 'package:furfeel_mobile/screens/auth/welcome_page.dart';
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

  // Load Inter (every weight the theme uses) BEFORE the first frame. A late
  // font swap makes TextPainter's deferred paint-time relayout disagree with
  // the cached layout size — the text_painter.dart `debugSize == size` assert
  // (flutter#79084). Preloading removes the race entirely.
  //
  // Bounded: google_fonts' HTTP fetch (google_fonts_base.dart, `client.get`)
  // has no timeout of its own. A dropped connection — restrictive network,
  // no signal on first launch — means this await never resolves and never
  // throws, so `runApp()` below is never reached and the native splash
  // (values-v31/styles.xml) is stuck on screen forever with nothing on top
  // of it to explain why. GoogleFonts already declares a system
  // `fontFamilyFallback`, so timing out just costs the anti-relayout guard
  // for the first frame, not the app being usable.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.inter(),
      GoogleFonts.inter(fontWeight: FontWeight.w500),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
    ]).timeout(const Duration(seconds: 3));
  } catch (_) {
    // Timed out or failed to fetch — proceed on the system font fallback
    // rather than hold the splash screen hostage.
  }

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
  static bool isProgressiveOnboarding = false;

  @override
  State<FurFeelApp> createState() => _FurFeelAppState();
}

class _FurFeelAppState extends State<FurFeelApp> {

  late final SupabaseClient _client = Supabase.instance.client;
  late final SupabaseFurFeelRepository _repository = SupabaseFurFeelRepository(_client);
  late final SettingsController _settings = SettingsController(_repository);
  final _navigatorKey = GlobalKey<NavigatorState>();

  // Cold-start gate: splash holds until the seen-flag is read AND the brand
  // beat has had a moment on screen, so the splash never just flickers.
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    if (_client.auth.currentSession != null) _settings.load();
    _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) {
        _settings.load();
        if (!FurFeelApp.isProgressiveOnboarding) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      }
      if (state.event == AuthChangeEvent.signedOut) {
        _settings.clear();
        StatusCache.clear(); // cached readings belong to the signed-out account
        // Sign-out can fire while AccountPage (or another screen) is pushed
        // on top of the home StreamBuilder -- pop back so the freshly
        // signed-out Welcome screen is actually visible, not a half-cleared
        // page left stranded on the stack (mirrors the sign-in fix above).
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });
    _bootstrap();
  }

  /// Minimum time the brand splash stays up. Short on purpose: it exists only
  /// so a fast start doesn't flash the logo for one frame, NOT to pad the
  /// launch. The cross-fade below covers the rest — a fixed 1.5s floor taxed
  /// every cold start even when everything was ready in 200ms.
  static const _minSplash = Duration(milliseconds: 400);

  Future<void> _bootstrap() async {
    await Future<void>.delayed(_minSplash);
    if (!mounted) return;
    setState(() {
      _splashDone = true;
    });
  }



  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ADDED: theme flows through ThemeData.extensions (FurFeelPalette) now —
    // MaterialApp owns light/dark/system switching via themeMode, so the old
    // full-tree rebuild + FurFeelTokens.isDark static are gone.
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return SettingsScope(
          controller: _settings,
          child: MaterialApp(
            title: 'FurFeel',
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: buildFurFeelTheme(),
            darkTheme: buildFurFeelTheme(dark: true),
            themeMode: _settings.themeMode,
            // Cross-fade out of the splash so the first real screen arrives
            // softly instead of cutting; this is what lets the floor above be
            // short without the launch looking like a flicker.
            home: AnimatedSwitcher(
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
              style: TextStyle(color: context.ff.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}
