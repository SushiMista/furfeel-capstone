// Documentation screenshot harness. Renders real screens (demo data) to PNGs.
// Run:  flutter test test/screenshots_test.dart --update-goldens
// Output: test/screenshots/*.png  (full scrollable page per file, real charts).
//
// Not a correctness test — it only regenerates docs images. Uses DemoRepository
// so there's no network/auth and the data is deterministic.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:furfeel_mobile/data/demo_repository.dart';
import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/screens/auth/consent_page.dart';
import 'package:furfeel_mobile/screens/auth/guided_setup_page.dart';
import 'package:furfeel_mobile/screens/auth/onboarding_page.dart';
import 'package:furfeel_mobile/screens/auth/splash_page.dart';
import 'package:furfeel_mobile/screens/auth/welcome_page.dart';
import 'package:furfeel_mobile/screens/dogs/care_tips_page.dart';
import 'package:furfeel_mobile/screens/dogs/device_pairing_page.dart';
import 'package:furfeel_mobile/screens/dogs/dog_detail_page.dart';
import 'package:furfeel_mobile/screens/dogs/dog_form_page.dart';
import 'package:furfeel_mobile/screens/home/root_shell.dart';
import 'package:furfeel_mobile/screens/observations/media_thread_page.dart';
import 'package:furfeel_mobile/screens/observations/observation_page.dart';
import 'package:furfeel_mobile/screens/observations/vet_review_page.dart';
import 'package:furfeel_mobile/screens/settings/about_pages.dart';
import 'package:furfeel_mobile/screens/settings/account_page.dart';
import 'package:furfeel_mobile/screens/settings/partner_clinics_page.dart';
import 'package:furfeel_mobile/screens/settings/settings_page.dart';
import 'package:furfeel_mobile/screens/vitals/detailed_log_page.dart';
import 'package:furfeel_mobile/screens/vitals/history_page.dart';
import 'package:furfeel_mobile/screens/vitals/vital_detail_page.dart';
import 'package:furfeel_mobile/theme/furfeel_theme.dart';

import 'fakes.dart';

const _w = 390.0; // logical phone width
const _dpr = 2.0; // crisp for docs without being huge

Future<void> _loadFont(String path, List<String> families) async {
  final bytes = File(path).readAsBytesSync().buffer.asByteData();
  for (final family in families) {
    await (FontLoader(family)..addFont(Future.value(bytes))).load();
  }
}

// google_fonts names families '<Family>_<variant>' (e.g. Inter_regular,
// Inter_800). Registering the (variable) Inter under every variant the theme
// uses makes GoogleFonts styles — app bar, buttons, nav bar — resolve to real
// Inter instead of tofu boxes. 'Inter' covers the textTheme we .apply() too.
const _interFamilies = [
  'Inter',
  'Inter_regular',
  'Inter_500',
  'Inter_600',
  'Inter_700',
  'Inter_800',
];

Future<void> _surface(WidgetTester t, double h) async {
  t.view.devicePixelRatio = _dpr;
  t.view.physicalSize = Size(_w * _dpr, h * _dpr);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Widget _wrap(Widget home, FurFeelRepository repo) {
  final base = buildFurFeelTheme();
  // Force the FontLoader-registered Inter onto every text style — GoogleFonts'
  // own family doesn't resolve in the sandbox, so its glyphs render as boxes.
  final theme = base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Inter'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
  );
  return SettingsScope(
    controller: SettingsController(repo),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: home,
    ),
  );
}

/// Let async data loads + a couple animation frames run, without hanging on
/// continuous (pulse/shimmer) animations that never settle.
Future<void> _load(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 180));
  }
}

const _probe = 400.0; // small surface so scrollable content overflows and its
// maxScrollExtent reveals the true page height (measured, never guessed).
const _fillHeight = 844.0; // iPhone-ish height for full-screen (non-scroll) layouts.

/// Tallest content height of the currently-pumped tree: probe surface + the
/// largest vertical scroll extent, or a device height for non-scrolling pages.
double _contentHeight(WidgetTester t) {
  final verticals = t
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((s) => s.position.axis == Axis.vertical)
      .toList();
  if (verticals.isEmpty) return _fillHeight;
  final maxExtent =
      verticals.map((s) => s.position.maxScrollExtent).reduce((a, b) => a > b ? a : b);
  return _probe + maxExtent + 24; // 24px bottom breathing room
}

void main() {
  // GoogleFonts can't fetch Inter in the test sandbox. Register a real Inter
  // (variable, all weights) under family 'Inter' — the exact family GoogleFonts
  // uses — so text resolves to it. Then disable runtime fetching and drop the
  // now-harmless "not found in assets" load errors so they don't fail the run.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFont('test/fonts/Inter.ttf', _interFamilies);
    // Material icons are a font too; unloaded they render as tofu boxes.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    final fontPaths = [
      if (flutterRoot != null) '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ];
    for (final path in fontPaths) {
      if (File(path).existsSync()) {
        await _loadFont(path, ['MaterialIcons']);
        break;
      }
    }
  });

  // Written to the repo-root docs/ folder (path is relative to this test file).
  Future<void> shot(WidgetTester t, String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../../docs/screenshots/mobile/$name.png'));

  // Fit the surface to the current tree's content (measured), then capture — no
  // trailing whitespace, no per-screen height guessing. The tree must already
  // be pumped; resizing in place preserves state (e.g. the selected tab).
  Future<void> probeAndShot(WidgetTester t, String name) async {
    await _surface(t, _probe);
    await _load(t); // load data + lay out at the probe height
    await _surface(t, _contentHeight(t));
    await t.pump(); // just relayout at the fitted height (data already loaded)
    await t.pump(const Duration(milliseconds: 120));
    await shot(t, name);
  }

  // flutter_test resets FlutterError.onError at the start of each test, so
  // doc-gen noise (google_fonts "not found", debug overflow stripes, dispose-
  // time ancestor lookups) must be filtered from inside the test body.
  void ignoreDocGenNoise() {
    const noise = ['font', 'overflowed', 'deactivated widget'];
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      final s = details.exception.toString();
      if (noise.any(s.contains)) return;
      prev?.call(details);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  // google_fonts' failed-load errors surface asynchronously (Zone level), not
  // through FlutterError.onError — swallow them here so they don't crash the run
  // at teardown. Any non-font async error still throws.
  Future<void> guarded(Future<void> Function() body) => runZonedGuarded(body,
      (e, _) {
    if (!e.toString().contains('font')) throw e;
  })!;

  testWidgets('demo tabs', (t) async {
    ignoreDocGenNoise();
    await guarded(() async {
      await _surface(t, _probe);
      final repo = DemoRepository();
      await t.pumpWidget(_wrap(
        RootShell(repository: repo, demo: true, onSignOut: () async {}),
        repo,
      ));
      await _load(t);

      // Home is tab 0 already.
      await probeAndShot(t, 'home');

      for (final label in ['Alerts', 'Trends', 'Profile', 'Chat']) {
        await _surface(t, _probe);
        await t.tap(find.bySemanticsLabel(RegExp(label)).first);
        await _load(t);
        await probeAndShot(t, label.toLowerCase());
      }
    });
  });

  testWidgets('all other screens', timeout: const Timeout(Duration(minutes: 30)), (t) async {
    ignoreDocGenNoise();
    await guarded(() async {
      final repo = DemoRepository();
      final dog = (await repo.fetchDogs()).first;
      // WelcomePage only needs a client for button navigation, not to render.
      // A real SupabaseClient starts a *periodic* token-refresh Timer that
      // flutter_test flags as still-pending at teardown — stop it right away.
      final client = SupabaseClient('https://demo.supabase.co', 'anon');
      client.auth.stopAutoRefresh();

      // Media thread needs a concrete submission + a reply; demo media is empty.
      final mediaRepo = FakeRepository()
        ..mediaMessages = [
          MediaMessage(
            id: 'm1',
            mediaSubmissionId: 'media-1',
            authorUserId: 'vet-1',
            authorName: 'Dr. Kim',
            body: 'Thanks — this angle helps a lot. Buddy looks relaxed here.',
            createdAt: DateTime(2026, 7, 16, 11),
          ),
        ];
      final submission = MediaSubmission(
        id: 'media-1',
        dogId: dog.id,
        storagePath: 'dogs/${dog.id}/obs.mp4',
        mediaType: 'video',
        createdAt: DateTime(2026, 7, 16, 9),
        note: 'Buddy paced a lot during the thunderstorm this afternoon.',
        reviewNote: 'Normal stress response to loud noise — no concern.',
        reviewedAt: DateTime(2026, 7, 16, 11),
      );

      final screens = <(String, Widget)>[
        ('dog_detail', DogDetailPage(repository: repo, dog: dog, dogsCount: 1)),
        ('history', HistoryView(repository: repo, dog: dog)),
        ('vital_heart_rate', VitalDetailPage(repository: repo, dog: dog, kind: VitalKind.heartRate)),
        ('detailed_log', DetailedLogPage(repository: repo, dog: dog)),
        ('observation', ObservationPage(repository: repo, dog: dog)),
        ('vet_review', VetReviewPage(repository: repo, dog: dog)),
        ('media_thread', MediaThreadPage(repository: mediaRepo, dog: dog, submission: submission)),
        ('device_pairing', DevicePairingPage(repository: repo, dog: dog)),
        ('care_tips', CareTipsPage(repository: repo)),
        ('dog_form', DogFormPage(repository: repo)),
        ('settings', const SettingsPage()),
        ('account', AccountPage(repository: repo, onSignOut: () async {})),
        ('partner_clinics', PartnerClinicsPage(repository: repo)),
        ('how_it_works', const HowItWorksPage()),
        ('privacy', const PrivacyPage()),
        ('about', const AboutPage()),
        // Auth flow.
        ('splash', const SplashPage()),
        ('welcome', WelcomePage(client: client)),
        ('onboarding', OnboardingPage(onDone: () {})),
        ('consent', ConsentPage(repository: repo, onAccepted: () {}, onSignOut: () async {})),
        ('guided_setup', GuidedSetupPage(repository: repo, onFinished: () async {}, onSignOut: () async {})),
      ];

      for (final (name, screen) in screens) {
        await _surface(t, _probe);
        await t.pumpWidget(_wrap(screen, repo));
        await probeAndShot(t, name);
      }

      await t.pumpWidget(const SizedBox()); // dispose the last screen's tree
      await t.pump(const Duration(seconds: 1));
    });
  });
}
