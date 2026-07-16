import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/push_registration.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/furfeel_logo.dart';
import '../widgets/skeletons.dart';
import 'alerts_tab.dart';
import 'dog_form_page.dart';
import 'guided_setup_page.dart';
import 'home_tab.dart';
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
  Unsubscribe? _unsubscribe;

  Dog? get _selectedDog {
    final dogs = _dogs;
    if (dogs == null || dogs.isEmpty) return null;
    return dogs.firstWhere((d) => d.id == _selectedDogId, orElse: () => dogs.first);
  }

  @override
  void initState() {
    super.initState();
    _loadDogs();
    // In-app registration path for push (docs/04). No tokenProvider yet: the
    // FCM/APNs credential wiring is a human step — see data/push_registration.dart.
    registerPushTokenIfAvailable(widget.repository);
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong loading your dogs. Pull to retry.';
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
      final results = await Future.wait<Object?>([
        widget.repository.fetchLatestReading(dogId),
        widget.repository.fetchLatestClassification(dogId),
        // Alerts back to 14 days-ish so week-over-week insights are honest.
        widget.repository.fetchAlerts(dogId, limit: 100),
        widget.repository.fetchDeviceForDog(dogId),
        widget.repository.fetchCareGuidance(),
        widget.repository.fetchDailyStressSummary(dogId),
        widget.repository.fetchHourlyStressPattern(dogId),
        widget.repository.fetchVetNoteFeed(dogId),
      ]);
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
      });
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
    } catch (_) {
      if (!mounted || _selectedDogId != dogId) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong loading your dog. Pull to retry.';
      });
    }
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

    if (dogs != null && dogs.isEmpty) return _buildOnboarding(context);

    final openAlerts = _alerts.where((a) => a.isOpen).length;

    return Scaffold(
      // QA: the brand logo owns the app bar; the dog switcher moves to a
      // compact chip on the trailing side.
      appBar: AppBar(
        title: const FurFeelLogo(),
        actions: [
          if (dogs != null && dog != null)
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
      body: _buildBody(dog),
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
      return _EmptyMessage(message: _error!, onRefresh: _loadDogs);
    }
    if (_loading || dog == null) {
      // Skeletons shaped like the real Home cards, not a spinner (docs/19 §5a).
      return const HomeSkeleton();
    }

    return switch (_tab) {
      0 => _error != null
          ? _EmptyMessage(message: _error!, onRefresh: _refresh)
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

/// Header dog switcher (docs/04: "A dog switcher in the header").
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

  /// Soft pill chip — readable against the app bar now that the brand logo
  /// owns the title slot (QA).
  Widget _chip({required bool caret}) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FurFeelTokens.space3,
          vertical: FurFeelTokens.space1,
        ),
        decoration: BoxDecoration(
          color: FurFeelTokens.brandSoft,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.name,
              style: TextStyle(
                fontSize: FurFeelTokens.typeBodyMobileSize,
                fontWeight: FontWeight.w700,
                color: FurFeelTokens.brandStrong,
              ),
            ),
            if (caret) Icon(Icons.arrow_drop_down, color: FurFeelTokens.brandStrong),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (dogs.length == 1) return Center(child: _chip(caret: false));
    return PopupMenuButton<String>(
      tooltip: 'Switch dog',
      onSelected: (value) {
        if (value == '_add') {
          onAddDog();
        } else {
          onSelected(value);
        }
      },
      itemBuilder: (context) => [
        for (final dog in dogs)
          PopupMenuItem(
            value: dog.id,
            child: Row(
              children: [
                if (dog.id == selected.id)
                  Icon(Icons.check, size: 18, color: FurFeelTokens.brand)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: FurFeelTokens.space2),
                Text(dog.name),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: '_add',
          child: Row(
            children: [
              Icon(Icons.add, size: 18, color: FurFeelTokens.inkMuted),
              SizedBox(width: FurFeelTokens.space2),
              Text('Add a dog…'),
            ],
          ),
        ),
      ],
      child: Center(child: _chip(caret: true)),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        children: [
          const SizedBox(height: 80),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: FurFeelTokens.inkMuted),
          ),
        ],
      ),
    );
  }
}
