import 'package:flutter/material.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/errors.dart';
import 'package:furfeel_mobile/widgets/retry_message.dart';
import 'package:furfeel_mobile/widgets/skeletons.dart';
import 'package:furfeel_mobile/screens/home/home_tab.dart';

/// Full detail for one dog, opened from a multi-dog Home card (QA item 9).
/// Self-loading: fetches the same data RootShell keeps for the selected dog
/// and renders the exact same rich Home content, plus live updates.
class DogDetailPage extends StatefulWidget {
  const DogDetailPage({
    super.key,
    required this.repository,
    required this.dog,
    required this.dogsCount,
  });

  final FurFeelRepository repository;
  final Dog dog;

  /// Total dogs on this account — the caller (MultiDogHomeTab) already has
  /// this list; passed through for the overview card, no extra query.
  final int dogsCount;

  @override
  State<DogDetailPage> createState() => _DogDetailPageState();
}

class _DogDetailPageState extends State<DogDetailPage> {
  TelemetryReading? _reading;
  StressClassification? _classification;
  List<DailyStressSummary> _daily = const [];
  Device? _device;
  List<CareGuidance> _guidance = const [];
  List<Alert> _alerts = const [];
  bool _loading = true;
  String? _error;
  Unsubscribe? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _load();
    _unsubscribe = widget.repository.subscribeToDog(
      widget.dog.id,
      onReading: (reading) {
        if (mounted) setState(() => _reading = reading);
      },
      onClassification: (classification) {
        if (mounted) setState(() => _classification = classification);
      },
    );
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = widget.repository;
    final dogId = widget.dog.id;
    try {
      final results = await Future.wait<Object?>([
        repo.fetchLatestReading(dogId),
        repo.fetchLatestClassification(dogId),
        repo.fetchDailyStressSummary(dogId, days: 7),
        repo.fetchDeviceForDog(dogId),
        repo.fetchCareGuidance(),
        repo.fetchAlerts(dogId, limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _reading = results[0] as TelemetryReading?;
        _classification = results[1] as StressClassification?;
        _daily = results[2] as List<DailyStressSummary>;
        _device = results[3] as Device?;
        _guidance = results[4] as List<CareGuidance>;
        _alerts = results[5] as List<Alert>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      // A failed load must not masquerade as "no data yet" (state audit).
      if (mounted) {
        setState(() {
          _loading = false;
          _error = loadErrorMessage(e, "${widget.dog.name}'s data");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    // Loaded: the immersive hero owns the top and carries its own back button
    // (leading), so no app bar. Loading/error have no hero, so a transparent
    // app bar (body extends behind it) provides a surface-disc back button.
    if (!_loading && _error == null) {
      return Scaffold(
        body: HomeTab(
          repository: widget.repository,
          dog: widget.dog,
          reading: _reading,
          classification: _classification,
          daily: _daily,
          device: _device,
          guidance: _guidance,
          onRefresh: _load,
          dogsCount: widget.dogsCount,
          alerts: _alerts,
          onBack: () => Navigator.of(context).maybePop(),
        ),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 40 + FurFeelTokens.space4,
        leading: Padding(
          padding: const EdgeInsets.only(left: FurFeelTokens.space3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: FurFeelTokens.shadowCard,
            ),
            child: Material(
              color: p.surface,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                customBorder: const CircleBorder(),
                child: Tooltip(
                  message: 'Back',
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back_ios_new, size: 18, color: p.ink),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const HomeSkeleton()
          : RetryMessage(message: _error!, onRefresh: _load),
    );
  }
}
