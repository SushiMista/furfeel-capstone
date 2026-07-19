import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/furfeel_repository.dart';
import '../data/push_registration.dart';
import '../data/settings_controller.dart';
import '../data/status_cache.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/furfeel_logo.dart';
import '../widgets/retry_message.dart';
import '../widgets/skeletons.dart';
import '../util/errors.dart';
import '../util/friendly_time.dart';
import '../util/perf.dart';
import 'alerts_tab.dart';
import 'consent_page.dart';
import 'dog_form_page.dart';
import 'guided_setup_page.dart';
import 'home_tab.dart';
import 'multi_dog_home.dart';
import 'profile_tab.dart';
import 'trends_tab.dart';

/// Owner-app shell (docs/04 Navigation): bottom tabs Home · Alerts · Trends ·
/// Profile with a dog switcher in the header (multi-dog accounts). Owns the
/// selected dog's live data + the Realtime subscription so every tab stays
/// current without its own socket.
class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.repository,
    required this.onSignOut,
    this.userEmail,
  });

  final FurFeelRepository repository;
  final Future<void> Function() onSignOut;
  final String? userEmail;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  List<Dog>? _dogs;
  String? _selectedDogId;
  int _tab = 0;

  /// Consent gate (docs/12): null = still checking, false = must accept the
  /// current policy before any monitoring data or media features show.
  bool? _consented;

  TelemetryReading? _latestReading;
  StressClassification? _latestClassification;
  List<Alert> _alerts = [];
  Device? _device;
  List<CareGuidance> _guidance = [];
  List<VetNoteFeedItem> _vetNotes = [];
  List<DailyStressSummary> _dailySummaries = [];
  List<HourlyStressBucket> _hourlyPattern = [];
  bool _loading = true;
  String? _error;

  /// Non-null while showing the offline last-known snapshot (docs/04):
  /// the timestamp the cache was written, surfaced in the banner.
  DateTime? _staleSince;
  Unsubscribe? _unsubscribe;

  Dog? get _selectedDog {
    final dogs = _dogs;
    if (dogs == null || dogs.isEmpty) return null;
    return dogs.firstWhere((d) => d.id == _selectedDogId, orElse: () => dogs.first);
  }

  @override
  void initState() {
    super.initState();
    // Consent first (docs/12): dogs, telemetry, and the realtime subscription
    // only start once the current policy version is confirmed accepted.
    _checkConsent().then((_) {
      if (mounted && _consented == true) _loadDogs();
    });
    // In-app registration path for push (docs/04). No tokenProvider yet: the
    // FCM/APNs credential wiring is a human step — see data/push_registration.dart.
    registerPushTokenIfAvailable(widget.repository);
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  static String get _consentCacheKey =>
      'furfeel_consent_confirmed_$kConsentPolicyVersion';

  Future<void> _checkConsent() async {
    try {
      final accepted =
          await widget.repository.hasAcceptedConsent(kConsentPolicyVersion);
      if (accepted) {
        // Remember the CONFIRMED acceptance so an offline cold start can show
        // the cached last-known status instead of dead-ending at the gate.
        // Only server-confirmed acceptances are cached — never an assumption.
        SharedPreferences.getInstance()
            .then((p) => p.setBool(_consentCacheKey, true));
      }
      if (mounted) setState(() => _consented = accepted);
    } catch (_) {
      // Can't verify (offline?). A previously CONFIRMED acceptance for this
      // exact policy version still counts (consents are append-only records);
      // otherwise show the gate — monitoring data must not render before
      // consent is confirmed (docs/12). Accepting retries.
      final cached =
          (await SharedPreferences.getInstance()).getBool(_consentCacheKey);
      if (mounted) setState(() => _consented = cached == true);
    }
  }

  Future<void> _loadDogs() async {
    try {
      final dogs = await widget.repository.fetchDogs();
      if (!mounted) return;
      setState(() {
        _dogs = dogs;
        _error = null;
        if (dogs.isEmpty) _loading = false;
      });
      final dog = _selectedDog;
      if (dog != null) await _selectDog(dog.id);
    } catch (e) {
      if (!mounted) return;
      // Offline resilience: fall back to the last-known snapshot (clearly
      // bannered as stale) instead of an error screen, when we have one.
      final cached = await StatusCache.load();
      if (!mounted) return;
      if (cached != null && (_dogs == null || _dogs!.isEmpty)) {
        setState(() {
          _dogs = cached.dogs;
          _selectedDogId = cached.selectedDogId ?? cached.dogs.firstOrNull?.id;
          _latestReading = cached.reading;
          _latestClassification = cached.classification;
          _staleSince = cached.savedAt;
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = loadErrorMessage(e, 'your dogs');
      });
    }
  }

  Future<void> _selectDog(String dogId) async {
    final changed = dogId != _selectedDogId;
    if (changed) {
      await _unsubscribe?.call();
      _unsubscribe = null;
      if (!mounted) return;
      setState(() {
        _selectedDogId = dogId;
        _loading = true;
        _latestReading = null;
        _latestClassification = null;
        _alerts = [];
        _device = null;
        _vetNotes = [];
        _dailySummaries = [];
        _hourlyPattern = [];
      });
    }
    await _loadDogData(dogId);
  }

  Future<void> _loadDogData(String dogId) async {
    try {
      // [perf] home_load: docs/20 ISO 25010 performance evidence.
      final results = await timed('home_load', () => Future.wait<Object?>([
        widget.repository.fetchLatestReading(dogId),
        widget.repository.fetchLatestClassification(dogId),
        // Alerts back to 14 days-ish so week-over-week insights are honest.
        widget.repository.fetchAlerts(dogId, limit: 100),
        widget.repository.fetchDeviceForDog(dogId),
        widget.repository.fetchCareGuidance(),
        widget.repository.fetchDailyStressSummary(dogId),
        widget.repository.fetchHourlyStressPattern(dogId),
        widget.repository.fetchVetNoteFeed(dogId),
      ]));
      if (!mounted || _selectedDogId != dogId) return;
      setState(() {
        _latestReading = results[0] as TelemetryReading?;
        _latestClassification = results[1] as StressClassification?;
        _alerts = results[2] as List<Alert>;
        _device = results[3] as Device?;
        _guidance = results[4] as List<CareGuidance>;
        _dailySummaries = results[5] as List<DailyStressSummary>;
        _hourlyPattern = results[6] as List<HourlyStressBucket>;
        _vetNotes = results[7] as List<VetNoteFeedItem>;
        _loading = false;
        _error = null;
        _staleSince = null;
      });
      // Fire-and-forget: persist the last-known snapshot for offline opens.
      StatusCache.save(
        dogs: _dogs ?? const [],
        selectedDogId: _selectedDogId,
        reading: _latestReading,
        classification: _latestClassification,
      );
      _unsubscribe ??= widget.repository.subscribeToDog(
        dogId,
        onReading: (reading) {
          if (!mounted) return;
          setState(() => _latestReading = reading);
        },
        onClassification: (classification) {
          if (!mounted) return;
          setState(() => _latestClassification = classification);
        },
        onAlert: (alert) {
          if (!mounted) return;
          setState(() => _alerts = [alert, ..._alerts]);
          _showAlertBanner(alert);
        },
        // QA: a fresh clinician note pops onto Home live (the realtime row has
        // no author identity, so refetch the enriched feed).
        onVetNote: () {
          widget.repository.fetchVetNoteFeed(dogId).then((notes) {
            if (mounted && _selectedDogId == dogId) {
              setState(() => _vetNotes = notes);
            }
          }).catchError((_) {});
        },
      );
    } catch (e) {
      if (!mounted || _selectedDogId != dogId) return;
      final cached = await StatusCache.load();
      if (!mounted || _selectedDogId != dogId) return;
      if (cached != null && cached.reading?.dogId == dogId && _latestReading == null) {
        setState(() {
          _latestReading = cached.reading;
          _latestClassification = cached.classification;
          _staleSince = cached.savedAt;
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = loadErrorMessage(e, 'your dog');
      });
    }
  }

  /// Owner-delight pass: a live alert lands as a gentle in-app banner while
  /// the app is open (push covers the closed-app case once FCM is wired).
  /// Honors the same preferences push will: master toggle + per-type mutes.
  void _showAlertBanner(Alert alert) {
    final settings = SettingsScope.of(context).settings;
    if (!settings.notificationsEnabled ||
        settings.mutedAlertTypes.contains(alert.type)) {
      return;
    }
    if (_tab == 1) return; // already looking at Alerts
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(alert.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            if (mounted) setState(() => _tab = 1);
          },
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    final dog = _selectedDog;
    if (dog != null) await _loadDogData(dog.id);
  }

  Future<void> _acknowledgeAlert(Alert alert) async {
    final updated = await widget.repository.acknowledgeAlert(alert.id);
    if (updated != null && mounted) {
      setState(() {
        _alerts = _alerts.map((x) => x.id == updated.id ? updated : x).toList();
      });
    }
  }

  Future<void> _addFirstDog() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => DogFormPage(repository: widget.repository)),
    );
    if (result != null) await _loadDogs();
  }

  @override
  Widget build(BuildContext context) {
    final dogs = _dogs;
    final dog = _selectedDog;

    // Consent gate first: no monitoring data or media until accepted.
    if (_consented == null) return const Scaffold(body: HomeSkeleton());
    if (_consented == false) {
      return ConsentPage(
        repository: widget.repository,
        onAccepted: () {
          setState(() => _consented = true);
          _loadDogs();
        },
        onSignOut: widget.onSignOut,
      );
    }

    if (dogs != null && dogs.isEmpty) return _buildOnboarding(context);

    final openAlerts = _alerts.where((a) => a.isOpen).length;

    return Scaffold(
      // QA: the brand logo owns the app bar; the dog switcher moves to a
      // compact chip on the trailing side.
      appBar: AppBar(
        title: const FurFeelLogo(),
        actions: [
          // Owner feedback: on the multi-dog Home the cards ARE the dog list,
          // so the switcher chip would be redundant there. It stays on
          // Alerts/Trends/Profile, which still need a selected dog.
          if (dogs != null &&
              dog != null &&
              !(_tab == 0 && dogs.length > 1) &&
              _tab != 3)
            Padding(
              padding: const EdgeInsets.only(right: FurFeelTokens.space3),
              child: _DogSwitcher(
                dogs: dogs,
                selected: dog,
                onSelected: _selectDog,
                onAddDog: _addFirstDog,
              ),
            ),
        ],
      ),
      body: _staleSince == null
          ? _buildBody(dog)
          : Column(children: [
              _OfflineBanner(since: _staleSince!),
              Expanded(child: _buildBody(dog)),
            ]),
      // Floating pill bar (modern-minimal): Scaffold reserves exactly the
      // bar's own rendered height (margin + pill), so tab content never
      // needs manual bottom padding -- the page background simply shows
      // through the margin around the pill, which is what reads as
      // "floating" rather than a bar flush with the screen edges.
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const FloatingNavDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Home',
          ),
          FloatingNavDestination(
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications,
            label: 'Alerts',
            badgeCount: openAlerts,
          ),
          const FloatingNavDestination(
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights,
            label: 'Trends',
          ),
          const FloatingNavDestination(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Dog? dog) {
    if (_error != null && dog == null) {
      return RetryMessage(message: _error!, onRefresh: _loadDogs);
    }
    if (_loading || dog == null) {
      // Skeletons shaped like the real Home cards, not a spinner (docs/19 §5a).
      return const HomeSkeleton();
    }

    return switch (_tab) {
      // QA item 9: multi-dog accounts get a glanceable card per dog; a
      // single-dog owner still lands straight on the rich detail.
      0 when (_dogs?.length ?? 0) > 1 =>
        MultiDogHomeTab(repository: widget.repository, dogs: _dogs!),
      0 => _error != null
          ? RetryMessage(message: _error!, onRefresh: _refresh)
          : HomeTab(
              repository: widget.repository,
              dog: dog,
              reading: _latestReading,
              classification: _latestClassification,
              daily: _dailySummaries,
              device: _device,
              guidance: _guidance,
              vetNotes: _vetNotes,
              onRefresh: _refresh,
            ),
      1 => AlertsTab(
          dog: dog,
          alerts: _alerts,
          onAcknowledge: _acknowledgeAlert,
          onRefresh: _refresh,
        ),
      2 => TrendsTab(
          repository: widget.repository,
          dog: dog,
          daily: _dailySummaries,
          hourly: _hourlyPattern,
          alerts: _alerts,
          onRefresh: _refresh,
        ),
      _ => ProfileTab(
          repository: widget.repository,
          dogs: _dogs ?? const [],
          userEmail: widget.userEmail,
          onDogsChanged: _loadDogs,
          onSignOut: widget.onSignOut,
        ),
    };
  }

  /// First-run onboarding (ADDED): the guided setup flow (docs/04 Onboarding —
  /// add your dog → pair the harness → done) instead of an empty dashboard.
  Widget _buildOnboarding(BuildContext context) {
    return GuidedSetupPage(
      repository: widget.repository,
      onFinished: _loadDogs,
      onSignOut: widget.onSignOut,
    );
  }
}

/// Header dog switcher — tapping the chip opens a bottom sheet with avatars,
/// names, breeds, and a brand checkmark on the active dog.
class _DogSwitcher extends StatelessWidget {
  const _DogSwitcher({
    required this.dogs,
    required this.selected,
    required this.onSelected,
    required this.onAddDog,
  });

  final List<Dog> dogs;
  final Dog selected;
  final void Function(String dogId) onSelected;
  final VoidCallback onAddDog;

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DogSwitcherSheet(
        dogs: dogs,
        selected: selected,
        onSelected: (id) {
          Navigator.of(context, rootNavigator: true).pop();
          onSelected(id);
        },
        onAddDog: () {
          Navigator.of(context, rootNavigator: true).pop();
          onAddDog();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = dogs.length > 1;
    return GestureDetector(
      onTap: hasMultiple ? () => _openSheet(context) : null,
      // AppBar actions get unbounded width, so a long dog name pushed this
      // Row past the app bar (RenderFlex overflow + the TextPainter paint
      // assert). Cap the chip; the name ellipsizes inside it.
      child: Tooltip(
        message: hasMultiple ? 'Switch dog' : selected.name,
        child: Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(
          horizontal: FurFeelTokens.space3,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.ff.brand.withValues(alpha: 0.12),
              context.ff.brand.withValues(alpha: 0.18),
            ],
          ),
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
          border: Border.all(
            color: context.ff.brand.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tiny paw avatar
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: context.ff.brand.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.pets, size: 13, color: context.ff.brandStrong),
            ),
            const SizedBox(width: 6),
            // Flexible + ellipsis: a long dog name must never push this Row
            // past the app-bar width (unconstrained Text here overflowed and
            // fed the TextPainter paint-time size assert).
            Flexible(
              child: Text(
                selected.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.ff.brandStrong,
                ),
              ),
            ),
            if (hasMultiple) ...[
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: context.ff.brandStrong),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

/// The bottom sheet content for switching between dogs.
class _DogSwitcherSheet extends StatelessWidget {
  const _DogSwitcherSheet({
    required this.dogs,
    required this.selected,
    required this.onSelected,
    required this.onAddDog,
  });

  final List<Dog> dogs;
  final Dog selected;
  final void Function(String dogId) onSelected;
  final VoidCallback onAddDog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: context.ff.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(FurFeelTokens.radiusLg),
        ),
        boxShadow: FurFeelTokens.shadowCard,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────────
            const SizedBox(height: FurFeelTokens.space3),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.ff.hairline,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
              ),
            ),
            const SizedBox(height: FurFeelTokens.space4),

            // ── Sheet title ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: FurFeelTokens.space5),
              child: Row(
                children: [
                  Icon(Icons.pets, size: 18, color: context.ff.brand),
                  const SizedBox(width: FurFeelTokens.space2),
                  Text(
                    'Your dogs',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.ff.brandInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FurFeelTokens.space3),
            Divider(color: context.ff.hairline, height: 1),

            // ── Dog list ─────────────────────────────────────────────────
            for (final dog in dogs) _DogRow(dog: dog, selected: selected, onTap: onSelected),

            Divider(color: context.ff.hairline, height: 1),

            // ── Add a dog ─────────────────────────────────────────────────
            InkWell(
              onTap: onAddDog,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FurFeelTokens.space5,
                  vertical: FurFeelTokens.space4,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.ff.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.ff.hairline,
                          width: 1.5,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                      child: Icon(Icons.add, color: context.ff.inkMuted, size: 22),
                    ),
                    const SizedBox(width: FurFeelTokens.space4),
                    Text(
                      'Add another dog',
                      style: textTheme.bodyMedium?.copyWith(
                        color: context.ff.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FurFeelTokens.space2),
          ],
        ),
      ),
    );
  }
}

/// A single dog row in the switcher sheet.
class _DogRow extends StatelessWidget {
  const _DogRow({
    required this.dog,
    required this.selected,
    required this.onTap,
  });

  final Dog dog;
  final Dog selected;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isActive = dog.id == selected.id;

    return InkWell(
      onTap: () => onTap(dog.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isActive
            ? context.ff.brand.withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: FurFeelTokens.space5,
          vertical: FurFeelTokens.space3,
        ),
        child: Row(
          children: [
            // Avatar circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? context.ff.brand.withValues(alpha: 0.12)
                    : context.ff.surfaceAlt,
                border: isActive
                    ? Border.all(
                        color: context.ff.brand,
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      )
                    : null,
              ),
              child: Icon(
                Icons.pets,
                size: 22,
                color: isActive ? context.ff.brand : context.ff.inkMuted,
              ),
            ),
            const SizedBox(width: FurFeelTokens.space4),

            // Name + breed
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dog.name,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? context.ff.brandInk
                          : context.ff.ink,
                    ),
                  ),
                  if (dog.breed != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      dog.breed!,
                      style: textTheme.bodySmall
                          ?.copyWith(color: context.ff.inkMuted),
                    ),
                  ],
                ],
              ),
            ),

            // Active checkmark
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isActive ? 1 : 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: context.ff.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offline last-known-reading banner (docs/04): word + icon, warm tint —
/// honest about staleness, never an error screen when we have data to show.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.since});

  final DateTime since;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ff.warmSoft,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FurFeelTokens.space4,
            vertical: FurFeelTokens.space2,
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 18, color: context.ff.warm),
              const SizedBox(width: FurFeelTokens.space2),
              Expanded(
                child: Text(
                  'Showing last known reading from '
                  '${friendlyTimestamp(since)} — pull to refresh.',
                  style: TextStyle(
                    color: context.ff.warm,
                    fontSize: FurFeelTokens.typeCaptionSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
