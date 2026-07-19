import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../util/errors.dart';
import '../widgets/retry_message.dart';
import '../widgets/skeletons.dart';
import 'home_tab.dart';

/// Full detail for one dog, opened from a multi-dog Home card (QA item 9).
/// Self-loading: fetches the same data RootShell keeps for the selected dog
/// and renders the exact same rich Home content, plus live updates.
class DogDetailPage extends StatefulWidget {
  const DogDetailPage({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<DogDetailPage> createState() => _DogDetailPageState();
}

class _DogDetailPageState extends State<DogDetailPage> {
  TelemetryReading? _reading;
  StressClassification? _classification;
  List<DailyStressSummary> _daily = const [];
  Device? _device;
  List<CareGuidance> _guidance = const [];
  List<VetNoteFeedItem> _vetNotes = const [];
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
        repo.fetchVetNoteFeed(dogId),
      ]);
      if (!mounted) return;
      setState(() {
        _reading = results[0] as TelemetryReading?;
        _classification = results[1] as StressClassification?;
        _daily = results[2] as List<DailyStressSummary>;
        _device = results[3] as Device?;
        _guidance = results[4] as List<CareGuidance>;
        _vetNotes = results[5] as List<VetNoteFeedItem>;
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.dog.name)),
      body: _loading
          ? const HomeSkeleton()
          : _error != null
              ? RetryMessage(message: _error!, onRefresh: _load)
              : HomeTab(
              repository: widget.repository,
              dog: widget.dog,
              reading: _reading,
              classification: _classification,
              daily: _daily,
              device: _device,
              guidance: _guidance,
              vetNotes: _vetNotes,
              onRefresh: _load,
            ),
    );
  }
}
