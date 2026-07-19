import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../widgets/stress_pill.dart';
import '../widgets/vitals_chart.dart';
import '../util/errors.dart';

const _historyLimit = 50;

/// Health history (docs/04): vitals trend, stress timeline, and recent
/// readings for one dog. Rendered as the History tab of the root shell.
class HistoryView extends StatefulWidget {
  const HistoryView({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<StressClassification> _classifications = [];
  List<TelemetryReading> _readings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        widget.repository.fetchRecentClassifications(widget.dog.id, limit: _historyLimit),
        widget.repository.fetchRecentReadings(widget.dog.id, limit: _historyLimit),
      ]);
      if (!mounted) return;
      setState(() {
        _classifications = results[0] as List<StressClassification>;
        _readings = results[1] as List<TelemetryReading>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loadErrorMessage(e, 'history');
      });
    }
  }

  @override
  void didUpdateWidget(covariant HistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dog switcher changed the selected dog — reload for the new one.
    if (oldWidget.dog.id != widget.dog.id) {
      setState(() => _loading = true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(FurFeelTokens.space4),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FurFeelTokens.space4),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.ff.statusHighOwner),
                      ),
                    ),
                  // ADDED: vitals trend chart (fl_chart) so history isn't only a list.
                  if (_readings.isNotEmpty) ...[
                    Text('VITALS TREND', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: FurFeelTokens.space2),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(FurFeelTokens.space4),
                        child: VitalsChart(readings: _readings.reversed.toList()),
                      ),
                    ),
                    const SizedBox(height: FurFeelTokens.space5),
                  ],
                  Text('STRESS TIMELINE', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: FurFeelTokens.space2),
                  if (_classifications.isEmpty)
                    _emptyPanel('No stress readings yet — '
                        'we\'ll chart them as they arrive')
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: FurFeelTokens.space2),
                        child: Column(
                          children: [
                            for (final c in _classifications) _TimelineTile(classification: c),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: FurFeelTokens.space5),
                  Text('READINGS', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: FurFeelTokens.space2),
                  if (_readings.isEmpty)
                    _emptyPanel('No readings yet — waiting for '
                        '${widget.dog.name}\'s harness to check in')
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final (i, r) in _readings.indexed) ...[
                            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                            _HistoryReadingTile(reading: r),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            );
  }

  Widget _emptyPanel(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        decoration: BoxDecoration(
          color: context.ff.surfaceAlt,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.ff.inkMuted),
        ),
      );
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.classification});

  final StressClassification classification;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FurFeelTokens.space4,
        vertical: FurFeelTokens.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _timestamp(classification.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          StressPill(level: classification.stressLevel),
          if (classification.score != null) ...[
            const SizedBox(width: FurFeelTokens.space3),
            Text(
              'score ${classification.score!.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryReadingTile extends StatelessWidget {
  const _HistoryReadingTile({required this.reading});

  final TelemetryReading reading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FurFeelTokens.space4,
        vertical: FurFeelTokens.space3,
      ),
      child: Row(
        children: [
          Expanded(child: Text(_timestamp(reading.capturedAt), style: textTheme.bodySmall)),
          Text(
            // Preferred unit app-wide (docs/04 Settings).
            'HR ${reading.heartRateBpm ?? '—'} · '
            'RR ${reading.respiratoryRateBpm ?? '—'} · '
            '${SettingsScope.of(context).formatTemperature(reading.bodyTemperatureC)}'
            '${SettingsScope.of(context).temperatureUnitLabel}',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _timestamp(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
