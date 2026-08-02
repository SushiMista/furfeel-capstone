import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/insights/biometrics.dart';
import 'package:furfeel_mobile/models/activity_state.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/curved_status_header.dart';

/// ADDED (QA): one screen per vital. The Home grid opens this with the current
/// reading; it shows the typical resting range for the dog (their clinic-set
/// baseline when available, otherwise the general reference the classifier
/// uses) and plain-language owner guidance. Informational only — ranges vary
/// by breed, size, and age; never a diagnosis.
enum VitalKind { heartRate, breathing, temperature, activity }

extension VitalKindInfo on VitalKind {
  String get label => switch (this) {
        VitalKind.heartRate => 'Heart rate',
        VitalKind.breathing => 'Breathing',
        VitalKind.temperature => 'Temperature',
        VitalKind.activity => 'Activity',
      };

  IconData get icon => switch (this) {
        VitalKind.heartRate => Icons.favorite_outline,
        VitalKind.breathing => Icons.air,
        VitalKind.temperature => Icons.thermostat_outlined,
        VitalKind.activity => Icons.directions_run_outlined,
      };

  /// Per-metric identity colour (ADR-023). Overrides the monochrome-chart rule
  /// for the owner Home; status still lives in the FurFeel-score hero.
  Color color(BuildContext context) => switch (this) {
        VitalKind.heartRate => context.ff.vitalHeart,
        VitalKind.breathing => context.ff.vitalBreathing,
        VitalKind.temperature => context.ff.vitalTemperature,
        VitalKind.activity => context.ff.vitalActivity,
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
  DogBaseline? _baseline;
  List<TelemetryReading> _recent = const [];

  @override
  void initState() {
    super.initState();
    widget.repository.fetchBaseline(widget.dog.id).then((b) {
      if (mounted) setState(() => _baseline = b);
    }).catchError((_) {});
    // Owner-delight pass: a small "last few hours" trend of just this vital.
    final now = DateTime.now();
    widget.repository
        .fetchReadingsBetween(widget.dog.id,
            now.subtract(const Duration(hours: 3)), now, limit: 400)
        .then((rows) {
      if (mounted) setState(() => _recent = rows);
    }).catchError((_) {});
  }

  double? _pick(TelemetryReading r, SettingsController settings) =>
      switch (widget.kind) {
        VitalKind.heartRate => r.heartRateBpm?.toDouble(),
        VitalKind.breathing => r.respiratoryRateBpm?.toDouble(),
        VitalKind.temperature => r.bodyTemperatureC == null
            ? null
            : double.parse(settings.formatTemperature(r.bodyTemperatureC)),
        VitalKind.activity => r.motionActivity,
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
      case VitalKind.temperature:
        if (b?.normalBodyTemperatureC != null) {
          final v = settings.formatTemperature(b!.normalBodyTemperatureC);
          return (
            value: 'around $v${settings.temperatureUnitLabel}',
            source: 'set by your clinic for ${widget.dog.name}',
          );
        }
        final lo = settings.formatTemperature(37.5);
        final hi = settings.formatTemperature(39.2);
        return (
          value: '$lo–$hi${settings.temperatureUnitLabel}',
          source: 'general reference for adult dogs',
        );
      case VitalKind.activity:
        return (
          value: 'below 0.6 when resting (scale 0–1)',
          source: 'how the harness measures movement',
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
        VitalKind.temperature =>
          'Dogs run warmer than people. A little variation through the day '
              'is normal; sustained readings above the typical range count '
              'toward the stress level and can be worth mentioning to your '
              'clinic.',
        VitalKind.activity =>
          'A 0-to-1 movement index from the harness motion sensor — 0 is '
              'still, 1 is constant motion. Restless pacing scores high even '
              'without exercise, which is why it feeds the stress level.',
      };

  VitalStatus? get _status => switch (widget.kind) {
        VitalKind.heartRate =>
          heartRateStatus(widget.reading?.heartRateBpm, _baseline),
        VitalKind.breathing =>
          respiratoryStatus(widget.reading?.respiratoryRateBpm, _baseline),
        VitalKind.temperature =>
          temperatureStatus(widget.reading?.bodyTemperatureC),
        VitalKind.activity => null,
      };

  ActivityState get _activityState => widget.reading == null
      ? ActivityState.noSignal
      : activityStateFrom(
          posture: widget.reading!.posture,
          motionActivity: widget.reading!.motionActivity,
        );

  List<FlSpot> _recentSpots(SettingsController settings) {
    final spots = <FlSpot>[];
    for (final (i, r) in _recent.indexed) {
      final v = _pick(r, settings);
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    return spots;
  }

  String _currentValue(SettingsController settings) {
    final r = widget.reading;
    return switch (widget.kind) {
      VitalKind.heartRate => r?.heartRateBpm?.toString() ?? '—',
      VitalKind.breathing => r?.respiratoryRateBpm?.toString() ?? '—',
      VitalKind.temperature => settings.formatTemperature(r?.bodyTemperatureC),
      VitalKind.activity => _activityState.label,
    };
  }

  String _unit(SettingsController settings) => switch (widget.kind) {
        VitalKind.heartRate => 'bpm',
        VitalKind.breathing => 'breaths/min',
        VitalKind.temperature => settings.temperatureUnitLabel,
        VitalKind.activity => '',
      };

  /// The vet-set normal for this vital (the clinic baseline), for the coloured
  /// line on the graph. Null when the clinic hasn't set one, or for activity.
  double? _baselineValue(SettingsController settings) {
    final b = _baseline;
    if (b == null) return null;
    return switch (widget.kind) {
      VitalKind.heartRate => b.restingHeartRateBpm?.toDouble(),
      VitalKind.breathing => b.restingRespiratoryRateBpm?.toDouble(),
      VitalKind.temperature => b.normalBodyTemperatureC == null
          ? null
          : double.parse(settings.formatTemperature(b.normalBodyTemperatureC)),
      VitalKind.activity => null,
    };
  }

  /// One concise, bold line for the hero under the value.
  String _heroDescription() {
    if (widget.reading == null) return 'Waiting for the next reading';
    if (widget.kind == VitalKind.activity) return _activityState.description;
    final s = _status;
    return s == null ? 'Live reading' : '${s.label} for ${widget.dog.name}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final settings = SettingsScope.of(context);
    final range = _typicalRange(settings);

    final unit = _unit(settings);
    return Scaffold(
      body: ListView(
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
            leading: HeaderCircleButton(
              icon: Icons.arrow_back_ios_new,
              tooltip: 'Back',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(FurFeelTokens.space4,
                FurFeelTokens.space3, FurFeelTokens.space4, FurFeelTokens.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          if (_recentSpots(settings).length >= 2) ...[
            const SizedBox(height: FurFeelTokens.space3),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(FurFeelTokens.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(context, 'Last 3 hours'),
                    const SizedBox(height: FurFeelTokens.space3),
                    SizedBox(
                      height: 100,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: _recentSpots(settings),
                              color: widget.kind.color(context),
                              barWidth: 2.4,
                              isCurved: true,
                              preventCurveOverShooting: true,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              // Soft fill beneath the line, in the metric colour.
                              belowBarData: BarAreaData(
                                show: true,
                                color:
                                    widget.kind.color(context).withValues(alpha: 0.12),
                              ),
                            ),
                          ],
                          // The vet-set normal: a coloured line across the graph
                          // (docs/22 v7). The value on the axis is highlighted in
                          // the same colour so the reading reads against it.
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              if (_baselineValue(settings) case final b?)
                                HorizontalLine(
                                  y: b,
                                  color: widget.kind.color(context),
                                  strokeWidth: 2,
                                  dashArray: const [6, 4],
                                ),
                            ],
                          ),
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                                color: context.ff.hairline, strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            bottomTitles: const AxisTitles(),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 34,
                                getTitlesWidget: (value, meta) => Text(
                                  meta.formattedValue,
                                  style: TextStyle(
                                    fontSize: FurFeelTokens.typeCaptionSize,
                                    color: context.ff.inkMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                        ),
                        duration: FurFeelTokens.motionSlow,
                      ),
                    ),
                  ],
                ),
              ),
            ).entrance(context, index: 1),
          ],
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
