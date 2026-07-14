import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/furfeel_repository.dart';
import 'data/settings_controller.dart';
import 'pages/root_shell.dart';
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
  late final SupabaseClient _client = Supabase.instance.client;
  late final SupabaseFurFeelRepository _repository = SupabaseFurFeelRepository(_client);
  late final SettingsController _settings = SettingsController(_repository);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_client.auth.currentSession != null) _settings.load();
    _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedIn) _settings.load();
      if (state.event == AuthChangeEvent.signedOut) _settings.clear();
    });
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
            home: StreamBuilder<AuthState>(
              stream: _client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                final session = _client.auth.currentSession;
                if (session == null) {
                  return WelcomePage(client: _client);
                }
                if (!_settings.loaded) return const _SplashScreen();
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

/// ADDED: animated splash shown while the signed-in user's settings load — a
/// soft paw beat instead of a spinner. Static under reduced motion.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    Widget paw = Icon(Icons.pets, size: 64, color: FurFeelTokens.brand);
    if (!reduce) {
      paw = paw
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.12, 1.12),
            duration: 700.ms,
            curve: Curves.easeInOut,
          )
          .fade(begin: 0.85, end: 1);
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            paw,
            const SizedBox(height: FurFeelTokens.space4),
            Text(
              'FurFeel',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: FurFeelTokens.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
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
