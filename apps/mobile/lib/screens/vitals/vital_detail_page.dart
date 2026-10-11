import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/insights/biometrics.dart';
import 'package:furfeel_mobile/models/activity_state.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/friendly_time.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/curved_status_header.dart';

/// ADDED (QA): one screen per vital. The Home grid opens this with the current
/// reading; it shows the typical resting range for the dog (their clinic-set
/// baseline when available, otherwise the general reference the classifier
/// uses) and plain-language owner guidance. Informational only — ranges vary
/// by breed, size, and age; never a diagnosis.
enum VitalKind { heartRate, breathing, activity, ambientTemperature }

enum _VitalTrendRange { today, sevenDays, pastWeek }

extension _VitalTrendRangeInfo on _VitalTrendRange {
  String get label => switch (this) {
    _VitalTrendRange.today => 'Today',
    _VitalTrendRange.sevenDays => '7 days',
    _VitalTrendRange.pastWeek => 'Past week',
  };
}

extension VitalKindInfo on VitalKind {
  String get label => switch (this) {
    VitalKind.heartRate => 'Heart rate',
    VitalKind.breathing => 'Breathing',
    VitalKind.activity => 'Activity',
    VitalKind.ambientTemperature => 'Ambient temp',
  };

  IconData get icon => switch (this) {
    VitalKind.heartRate => Icons.favorite_outline,
    VitalKind.breathing => Icons.air,
    VitalKind.activity => Icons.directions_run_outlined,
    VitalKind.ambientTemperature => Icons.thermostat_outlined,
  };

  /// Per-metric identity colour (ADR-024). Overrides the monochrome-chart rule
  /// for the owner Home; status still lives in the FurFeel-score hero.
  Color color(BuildContext context) => switch (this) {
    VitalKind.heartRate => context.ff.vitalHeart,
    VitalKind.breathing => context.ff.vitalBreathing,
    VitalKind.activity => context.ff.vitalActivity,
    VitalKind.ambientTemperature => const Color(
      0xFFF59E0B,
    ), // Warm amber for temperature
  };
}

/// The metric-card anatomy header (docs/22): a small icon + a bold, sentence-
/// case label. Replaces the old clinical ALL-CAPS `labelSmall` section labels.
Widget _sectionHeader(BuildContext context, String text, {IconData? icon}) {
  return Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: context.ff.brand),
        const SizedBox(width: FurFeelTokens.space2),
      ],
      Text(
        text,
        style: TextStyle(
          fontSize: FurFeelTokens.typeH3Size,
          fontWeight: FurFeelTokens.typeH3Weight,
          color: context.ff.ink,
        ),
      ),
    ],
  );
}

class VitalDetailPage extends StatefulWidget {
  const VitalDetailPage({
    super.key,
    required this.repository,
    required this.dog,
    required this.kind,
    this.reading,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final VitalKind kind;
  final TelemetryReading? reading;

  @override
  State<VitalDetailPage> createState() => _VitalDetailPageState();
}

class _VitalDetailPageState extends State<VitalDetailPage> {
  final _scroll = ScrollController();
  DogBaseline? _baseline;
  List<TelemetryReading> _recent = const [];
  _VitalTrendRange _trendRange = _VitalTrendRange.today;
  bool _trendLoading = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.repository
        .fetchBaseline(widget.dog.id)
        .then((b) {
          if (mounted) setState(() => _baseline = b);
        })
        .catchError((_) {});
    _loadTrend();
  }

  ({DateTime start, DateTime end}) _trendWindow(DateTime now) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday % 7));
    return switch (_trendRange) {
      _VitalTrendRange.today => (start: todayStart, end: now),
      _VitalTrendRange.sevenDays => (
        start: weekStart,
        end: weekStart.add(const Duration(days: 7)),
      ),
      _VitalTrendRange.pastWeek => (
        start: weekStart.subtract(const Duration(days: 7)),
        end: weekStart,
      ),
    };
  }

  Future<void> _loadTrend() async {
    setState(() => _trendLoading = true);
    final now = DateTime.now();
    final window = _trendWindow(now);
    widget.repository
        .fetchReadingsBetween(
          widget.dog.id,
          window.start,
          window.end,
          limit: 1000,
        )
        .then((rows) {
          if (!mounted) return;
          setState(() {
            _recent = rows;
            _trendLoading = false;
          });
        })
        .catchError((_) {
          if (mounted) setState(() => _trendLoading = false);
        });
  }

  void _selectTrendRange(_VitalTrendRange range) {
    if (range == _trendRange) return;
    setState(() {
      _trendRange = range;
      _recent = const [];
    });
    _loadTrend();
  }

  double? _pick(TelemetryReading r, SettingsController settings) =>
      switch (widget.kind) {
        VitalKind.heartRate => r.heartRateBpm?.toDouble(),
        VitalKind.breathing => r.respiratoryRateBpm?.toDouble(),
        VitalKind.activity => r.motionActivity,
        VitalKind.ambientTemperature =>
          r.ambientTemperatureC == null
              ? null
              : (settings.useFahrenheit
                    ? r.ambientTemperatureC! * 9 / 5 + 32
                    : r.ambientTemperatureC),
      };

  // Owner-friendly reference ranges. Baseline (clinic-set) wins; the general
  // range matches the classifier's provisional global defaults (docs/08 /
  // classifier_config.json) so the app never contradicts its own alerts.
  ({String value, String source}) _typicalRange(SettingsController settings) {
    final b = _baseline;
    switch (widget.kind) {
      case VitalKind.heartRate:
        if (b?.restingHeartRateBpm != null) {
          return (
            value: 'around ${b!.restingHeartRateBpm} bpm at rest',
            source: 'set by your clinic for ${widget.dog.name}',
          );
        }
        return (
          value: '60–120 bpm at rest',
          source: 'general reference for adult dogs',
        );
      case VitalKind.breathing:
        if (b?.restingRespiratoryRateBpm != null) {
          return (
            value: 'around ${b!.restingRespiratoryRateBpm} breaths/min at rest',
            source: 'set by your clinic for ${widget.dog.name}',
          );
        }
        return (
          value: '15–35 breaths/min at rest',
          source: 'general reference for adult dogs',
        );
      case VitalKind.activity:
        return (
          value: 'below 0.6 when resting (scale 0–1)',
          source: 'how the harness measures movement',
        );
      case VitalKind.ambientTemperature:
        return (
          value: settings.useFahrenheit
              ? '64–75 °F indoors'
              : '18–24 °C indoors',
          source: 'comfortable range for most dogs',
        );
    }
  }

  String get _whatItMeans => switch (widget.kind) {
    VitalKind.heartRate =>
      'The harness reads your dog\'s pulse continuously. Smaller dogs '
          'naturally run faster than larger ones, and excitement, play, or '
          'heat push it up for a while — that\'s normal. FurFeel looks at '
          'how far it sits above your dog\'s own resting level, and for '
          'how long, before it counts toward stress.',
    VitalKind.breathing =>
      'Breaths per minute, measured at the chest. Panting after play or '
          'in warm weather is expected; fast breathing while resting in a '
          'cool, calm place is what FurFeel watches for.',
    VitalKind.activity =>
      'A 0-to-1 movement index from the harness motion sensor — 0 is '
          'still, 1 is constant motion. Restless pacing scores high even '
          'without exercise, which is why it feeds the stress level.',
    VitalKind.ambientTemperature =>
      'The temperature immediately surrounding the harness. It helps '
          'FurFeel understand if your dog is panting or restless because '
          'of the heat, rather than anxiety or pain.',
  };

  bool _hasMetric(TelemetryReading reading) => switch (widget.kind) {
    VitalKind.heartRate => reading.heartRateBpm != null,
    VitalKind.breathing => reading.respiratoryRateBpm != null,
    VitalKind.activity =>
      reading.motionActivity != null || reading.posture != null,
    VitalKind.ambientTemperature => reading.ambientTemperatureC != null,
  };

  TelemetryReading? _latestMetricReading() {
    final readings = [?widget.reading, ..._recent].where(_hasMetric).toList()
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return readings.firstOrNull;
  }

  VitalStatus? get _status => switch (widget.kind) {
    VitalKind.heartRate => heartRateStatus(
      _latestMetricReading()?.heartRateBpm,
      _baseline,
    ),
    VitalKind.breathing => respiratoryStatus(
      _latestMetricReading()?.respiratoryRateBpm,
      _baseline,
    ),
    VitalKind.activity => null,
    VitalKind.ambientTemperature => null,
  };

  ActivityState get _activityState => _latestMetricReading() == null
      ? ActivityState.noSignal
      : activityStateFrom(
          posture: _latestMetricReading()!.posture,
          motionActivity: _latestMetricReading()!.motionActivity,
        );

  double _xForReading(TelemetryReading reading, DateTime start) {
    final minutes = reading.capturedAt.difference(start).inMinutes.toDouble();
    return switch (_trendRange) {
      _VitalTrendRange.today => (minutes / 60).clamp(0, 24).toDouble(),
      _VitalTrendRange.sevenDays || _VitalTrendRange.pastWeek =>
        (minutes / Duration.minutesPerDay).clamp(0, 7).toDouble(),
    };
  }

  List<FlSpot> _recentSpots(SettingsController settings, DateTime start) {
    final spots = <FlSpot>[];
    for (final r in _recent) {
      final v = _pick(r, settings);
      if (v != null) spots.add(FlSpot(_xForReading(r, start), v));
    }
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  double get _chartMaxX => switch (_trendRange) {
    _VitalTrendRange.today => 24,
    _VitalTrendRange.sevenDays || _VitalTrendRange.pastWeek => 7,
  };

  ({double min, double max, double interval}) _chartScale(
    SettingsController settings,
    List<FlSpot> spots,
  ) {
    final base = switch (widget.kind) {
      // Stable IoT-debug ranges: the same values should draw in the same place
      // unless a sensor value falls outside the normal debugging window.
      VitalKind.heartRate => (min: 40.0, max: 220.0, interval: 40.0),
      VitalKind.breathing => (min: 0.0, max: 80.0, interval: 20.0),
      VitalKind.activity => (min: 0.0, max: 1.0, interval: 0.25),
      VitalKind.ambientTemperature =>
        settings.useFahrenheit
            ? (min: 32.0, max: 113.0, interval: 20.0)
            : (min: 0.0, max: 45.0, interval: 10.0),
    };

    var min = base.min;
    var max = base.max;
    for (final spot in spots) {
      min = math.min(min, spot.y);
      max = math.max(max, spot.y);
    }
    if (_baselineValue(settings) case final baseline?) {
      min = math.min(min, baseline);
      max = math.max(max, baseline);
    }

    final interval = base.interval;
    return (
      min: (min / interval).floor() * interval,
      max: (max / interval).ceil() * interval,
      interval: interval,
    );
  }

  String _metricValueLabel(double value, SettingsController settings) {
    final number = switch (widget.kind) {
      VitalKind.activity =>
        value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), ''),
      VitalKind.ambientTemperature => value.toStringAsFixed(1),
      VitalKind.heartRate || VitalKind.breathing => value.round().toString(),
    };
    final unit = _unit(settings);
    return unit.isEmpty ? number : '$number $unit';
  }

  String get _sparseTrendMessage {
    final label = widget.kind.label.toLowerCase();
    if (_trendLoading) return 'Loading $label readings...';
    final window = _trendWindow(DateTime.now());
    if (_recentSpots(SettingsScope.of(context), window.start).isEmpty) {
      return 'No $label readings in this range yet.';
    }
    return 'Only one $label reading in this range.';
  }

  String _currentValue(SettingsController settings) {
    final r = _latestMetricReading();
    return switch (widget.kind) {
      VitalKind.heartRate => r?.heartRateBpm?.toString() ?? '—',
      VitalKind.breathing => r?.respiratoryRateBpm?.toString() ?? '—',
      VitalKind.activity => _activityState.label,
      VitalKind.ambientTemperature =>
        r?.ambientTemperatureC == null
            ? '—'
            : (settings.useFahrenheit
                      ? (r!.ambientTemperatureC! * 9 / 5 + 32)
                      : r!.ambientTemperatureC!)
                  .toStringAsFixed(1),
    };
  }

  String _unit(SettingsController settings) => switch (widget.kind) {
    VitalKind.heartRate => 'bpm',
    VitalKind.breathing => 'breaths/min',
    VitalKind.activity => '',
    VitalKind.ambientTemperature => settings.useFahrenheit ? '°F' : '°C',
  };

  /// The vet-set normal for this vital (the clinic baseline), for the coloured
  /// line on the graph. Null when the clinic hasn't set one, or for activity.
  double? _baselineValue(SettingsController settings) {
    final b = _baseline;
    if (b == null) return null;
    return switch (widget.kind) {
      VitalKind.heartRate => b.restingHeartRateBpm?.toDouble(),
      VitalKind.breathing => b.restingRespiratoryRateBpm?.toDouble(),
      VitalKind.activity => null,
      VitalKind.ambientTemperature => null,
    };
  }

  /// One concise, bold line for the hero under the value.
  String _heroDescription() {
    if (_latestMetricReading() == null) return 'Waiting for the next reading';
    if (widget.kind == VitalKind.activity) return _activityState.description;
    if (widget.kind == VitalKind.ambientTemperature) {
      return 'Local harness temperature';
    }
    final s = _status;
    return s == null ? 'Live reading' : '${s.label} for ${widget.dog.name}';
  }

  String _lastMetricUpdateLabel() {
    final reading = _latestMetricReading();
    final label = widget.kind.label.toLowerCase();
    if (reading == null) return 'No $label yet';
    return 'Last $label ${clockTime(reading.capturedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final settings = SettingsScope.of(context);
    final range = _typicalRange(settings);
    final trendWindow = _trendWindow(DateTime.now());
    final recentSpots = _recentSpots(settings, trendWindow.start);
    final chartScale = _chartScale(settings, recentSpots);
    final latestTrendValue = recentSpots.isEmpty ? null : recentSpots.last.y;
    final lowTrendValue = recentSpots.isEmpty
        ? null
        : recentSpots.map((s) => s.y).reduce(math.min);
    final highTrendValue = recentSpots.isEmpty
        ? null
        : recentSpots.map((s) => s.y).reduce(math.max);
    final trendSummary = lowTrendValue == null || highTrendValue == null
        ? '--'
        : lowTrendValue == highTrendValue
        ? _metricValueLabel(highTrendValue, settings)
        : '${_metricValueLabel(lowTrendValue, settings)} - ${_metricValueLabel(highTrendValue, settings)}';
    final sampleLabel = _trendLoading
        ? 'Loading'
        : '${recentSpots.length} ${recentSpots.length == 1 ? 'sample' : 'samples'}';

    final unit = _unit(settings);
    return Scaffold(
      body: ListView(
        controller: _scroll,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        children: [
          // Immersive metric-coloured hero with the curved divider (docs/22 v7).
          CurvedStatusHeader(
            color: widget.kind.color(context),
            title: widget.kind.label,
            mark: widget.kind.icon,
            value: _currentValue(settings),
            unit: unit.isEmpty ? null : unit,
            description: _heroDescription(),
            scroll: _scroll,
            chips: [
              HeaderChip(
                icon: Icons.sensors_outlined,
                label: _lastMetricUpdateLabel(),
              ),
            ],
            leading: HeaderCircleButton(
              icon: Icons.arrow_back_ios_new,
              tooltip: 'Back',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FurFeelTokens.space4,
              FurFeelTokens.space3,
              FurFeelTokens.space4,
              FurFeelTokens.space6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: FurFeelTokens.space3),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FurFeelTokens.space4,
                      FurFeelTokens.space5,
                      FurFeelTokens.space4,
                      FurFeelTokens.space5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: widget.kind
                                    .color(context)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  FurFeelTokens.radiusMd,
                                ),
                              ),
                              child: Icon(
                                widget.kind.icon,
                                size: 20,
                                color: widget.kind.color(context),
                              ),
                            ),
                            const SizedBox(width: FurFeelTokens.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.kind.label,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: context.ff.ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _trendRange.label,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: context.ff.inkMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              sampleLabel,
                              style: textTheme.bodySmall?.copyWith(
                                color: context.ff.inkMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: FurFeelTokens.space4),
                        Text(
                          trendSummary,
                          style: textTheme.headlineMedium?.copyWith(
                            color: context.ff.ink,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: FurFeelTokens.space3),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                widget.kind
                                    .color(context)
                                    .withValues(alpha: 0.10),
                                widget.kind
                                    .color(context)
                                    .withValues(alpha: 0.03),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              FurFeelTokens.radiusLg,
                            ),
                          ),
                          child: SizedBox(
                            height: 126,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                              child: recentSpots.length < 2
                                  ? Center(
                                      child: Text(
                                        _sparseTrendMessage,
                                        textAlign: TextAlign.center,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: context.ff.inkMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : LineChart(
                                      LineChartData(
                                        minX: 0,
                                        maxX: _chartMaxX,
                                        minY: chartScale.min,
                                        maxY: chartScale.max,
                                        clipData: const FlClipData.all(),
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots: recentSpots,
                                            color: widget.kind.color(context),
                                            barWidth: 3,
                                            isCurved: recentSpots.length > 2,
                                            preventCurveOverShooting: true,
                                            isStrokeCapRound: true,
                                            dotData: const FlDotData(
                                              show: false,
                                            ),
                                            belowBarData: BarAreaData(
                                              show: true,
                                              color: widget.kind
                                                  .color(context)
                                                  .withValues(alpha: 0.10),
                                            ),
                                          ),
                                        ],
                                        gridData: const FlGridData(show: false),
                                        titlesData: const FlTitlesData(
                                          show: false,
                                        ),
                                        borderData: FlBorderData(show: false),
                                        lineTouchData: const LineTouchData(
                                          enabled: false,
                                        ),
                                      ),
                                      duration: FurFeelTokens.motionSlow,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: FurFeelTokens.space3),
                        _TrendRangePicker(
                          selected: _trendRange,
                          onSelected: _selectTrendRange,
                        ),
                        const SizedBox(height: FurFeelTokens.space3),
                        Row(
                          children: [
                            Expanded(
                              child: _TrendStat(
                                label: 'Samples',
                                value: _trendLoading
                                    ? '...'
                                    : recentSpots.length.toString(),
                              ),
                            ),
                            const SizedBox(width: FurFeelTokens.space2),
                            Expanded(
                              child: _TrendStat(
                                label: 'Latest',
                                value: latestTrendValue == null
                                    ? '-'
                                    : _metricValueLabel(
                                        latestTrendValue,
                                        settings,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).entrance(context, index: 1),
                const SizedBox(height: FurFeelTokens.space3),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(FurFeelTokens.space5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(context, 'Typical at rest'),
                        const SizedBox(height: FurFeelTokens.space2),
                        Text(range.value, style: textTheme.titleMedium),
                        const SizedBox(height: FurFeelTokens.space1),
                        Text(range.source, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ).entrance(context, index: 1),
                const SizedBox(height: FurFeelTokens.space3),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(FurFeelTokens.space5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(context, 'What this means'),
                        const SizedBox(height: FurFeelTokens.space2),
                        Text(_whatItMeans, style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ).entrance(context, index: 2),
                const SizedBox(height: FurFeelTokens.space4),
                Text(
                  'Typical ranges vary with breed, size, and age — your clinic can '
                  'set ${widget.dog.name}\'s own baseline. Decision support, never '
                  'a diagnosis.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ).entrance(context, index: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendStat extends StatelessWidget {
  const _TrendStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.ff.surfaceAlt,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          border: Border.all(color: context.ff.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FurFeelTokens.space3,
            vertical: FurFeelTokens.space2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.ff.inkMuted,
                  fontSize: FurFeelTokens.typeCaptionSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.ff.ink,
                  fontSize: FurFeelTokens.typeBodyMobileSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendRangePicker extends StatelessWidget {
  const _TrendRangePicker({required this.selected, required this.onSelected});

  final _VitalTrendRange selected;
  final ValueChanged<_VitalTrendRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.ff.surfaceAlt,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
        border: Border.all(color: context.ff.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (final range in _VitalTrendRange.values)
              Expanded(
                child: _TrendRangeButton(
                  range: range,
                  selected: range == selected,
                  onTap: () => onSelected(range),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendRangeButton extends StatelessWidget {
  const _TrendRangeButton({
    required this.range,
    required this.selected,
    required this.onTap,
  });

  final _VitalTrendRange range;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? context.ff.surface : Colors.transparent;
    final fg = selected ? context.ff.ink : context.ff.inkMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
        child: AnimatedContainer(
          duration: FurFeelTokens.motionFast,
          padding: const EdgeInsets.symmetric(vertical: FurFeelTokens.space2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: context.ff.ink.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            range.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: FurFeelTokens.typeCaptionSize,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
