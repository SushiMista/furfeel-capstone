import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/exports.dart';
import '../util/save_file.dart';
import '../util/errors.dart';
import '../util/full_export.dart';

/// Detailed Log, redesigned (QA item 13): friendly per-vital mini-dashboards
/// over a selectable date range, with downloadable exports — CSV always, plus
/// a shareable PDF health report. Raw numbers stay one tap away, not in your
/// face (docs/04: power-user page).
class DetailedLogPage extends StatefulWidget {
  const DetailedLogPage({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<DetailedLogPage> createState() => _DetailedLogPageState();
}

class _DetailedLogPageState extends State<DetailedLogPage> {
  /// Preset range in days; null = custom range picked on the calendar.
  int? _presetDays = 1;
  DateTimeRange? _customRange;

  List<TelemetryReading> _readings = const [];
  List<StressClassification> _classifications = const [];
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  DateTimeRange get _range {
    final custom = _customRange;
    if (custom != null) {
      // Include the whole final day.
      return DateTimeRange(
        start: custom.start,
        end: custom.end.add(const Duration(days: 1)),
      );
    }
    final now = DateTime.now();
    return DateTimeRange(
      start: now.subtract(Duration(days: _presetDays ?? 1)),
      end: now,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final range = _range;
    try {
      final results = await Future.wait<Object>([
        widget.repository.fetchReadingsBetween(widget.dog.id, range.start, range.end),
        widget.repository
            .fetchClassificationsBetween(widget.dog.id, range.start, range.end),
      ]);
      if (!mounted) return;
      setState(() {
        _readings = results[0] as List<TelemetryReading>;
        _classifications = results[1] as List<StressClassification>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = loadErrorMessage(e, 'the log');
      });
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: 'Pick the period to look at',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _presetDays = null;
    });
    await _load();
  }

  String get _fileStem {
    final r = _range;
    String d(DateTime t) =>
        '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
    final name = widget.dog.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'furfeel-$name-${d(r.start)}-${d(r.end)}';
  }

  Future<void> _exportCsv() => _export(() async {
        final csv = buildReadingsCsv(_readings);
        await saveOrShareFile(
            Uint8List.fromList(csv.codeUnits), '$_fileStem.csv', 'text/csv');
      });

  Future<void> _exportPdf() => _export(() async {
        final range = _range;
        // Owner + clinic + alerts turn the export into a transferable record
        // (owner feedback) — same document another clinic can file.
        final extras = await Future.wait<Object>([
          widget.repository.fetchMyProfile(),
          widget.repository.fetchClinics(),
          widget.repository.fetchAlerts(widget.dog.id, limit: 100),
        ]);
        Clinic? clinic;
        for (final c in extras[1] as List<Clinic>) {
          if (c.id == widget.dog.clinicId) clinic = c;
        }
        final bytes = await buildHealthReportPdf(
          dog: widget.dog,
          from: range.start,
          to: range.end,
          readings: _readings,
          classifications: _classifications,
          owner: extras[0] as UserProfile,
          clinic: clinic,
          alerts: extras[2] as List<Alert>,
        );
        await saveOrShareFile(bytes, '$_fileStem.pdf', 'application/pdf');
      });

  // ADDED (step 14, docs/12): the complete per-dog archive — every record the
  // owner can read under RLS, paged past the PostgREST row cap, one JSON file.
  Future<void> _exportEverything() => _export(() async {
        final dogId = widget.dog.id;
        final results = await Future.wait<Object?>([
          fetchAllReadings(widget.repository, dogId),
          fetchAllClassifications(widget.repository, dogId),
          widget.repository.fetchMyProfile(),
          widget.repository.fetchBaseline(dogId),
          widget.repository.fetchDeviceForDog(dogId),
          widget.repository.fetchAlerts(dogId, limit: 1000),
          widget.repository.fetchVetNotes(dogId, limit: 1000),
          widget.repository.fetchStressLabels(dogId, limit: 1000),
          widget.repository.fetchMediaSubmissions(dogId, limit: 1000),
        ]);
        final json = buildFullExportJson(
          dog: widget.dog,
          owner: results[2] as UserProfile,
          baseline: results[3] as DogBaseline?,
          device: results[4] as Device?,
          readings: results[0] as List<TelemetryReading>,
          classifications: results[1] as List<StressClassification>,
          alerts: results[5] as List<Alert>,
          vetNotes: results[6] as List<VetNote>,
          stressLabels: results[7] as List<StressLabelEntry>,
          media: results[8] as List<MediaSubmission>,
        );
        final name =
            widget.dog.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
        await saveOrShareFile(Uint8List.fromList(utf8.encode(json)),
            'furfeel-$name-everything.json', 'application/json');
      });

  Future<void> _export(Future<void> Function() run) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await run();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(actionErrorMessage(e, 'The export')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final settings = SettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.dog.name}\'s detailed log')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(FurFeelTokens.space4),
          children: [
            // ── Range selection ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('24h')),
                      ButtonSegment(value: 7, label: Text('7d')),
                      ButtonSegment(value: 30, label: Text('30d')),
                    ],
                    emptySelectionAllowed: true,
                    selected: {?_presetDays},
                    onSelectionChanged: (sel) {
                      if (sel.isEmpty) return;
                      setState(() {
                        _presetDays = sel.first;
                        _customRange = null;
                      });
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: FurFeelTokens.space2),
                IconButton.outlined(
                  tooltip: 'Pick dates',
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.calendar_month_outlined, size: 20),
                ),
              ],
            ),
            if (_customRange != null) ...[
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                '${_dayLabel(_customRange!.start)} – ${_dayLabel(_customRange!.end)}',
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: FurFeelTokens.space4),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: FurFeelTokens.space4),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.ff.statusHighOwner)),
              ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(FurFeelTokens.space6),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_readings.isEmpty)
              Container(
                padding: const EdgeInsets.all(FurFeelTokens.space5),
                decoration: BoxDecoration(
                  color: context.ff.surfaceAlt,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                ),
                child: Text(
                  'No readings in this period — try a wider range.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.ff.inkMuted),
                ),
              )
            else ...[
              _VitalChartCard(
                title: 'Heart rate',
                unit: 'bpm',
                color: context.ff.statusHighOwner,
                readings: _readings,
                pick: (r) => r.heartRateBpm?.toDouble(),
              ),
              _VitalChartCard(
                title: 'Breathing',
                unit: 'breaths/min',
                color: context.ff.accent,
                readings: _readings,
                pick: (r) => r.respiratoryRateBpm?.toDouble(),
              ),
              _VitalChartCard(
                title: 'Body temperature',
                unit: settings.temperatureUnitLabel,
                color: context.ff.warm,
                readings: _readings,
                pick: (r) => r.bodyTemperatureC == null
                    ? null
                    : double.parse(settings.formatTemperature(r.bodyTemperatureC)),
                decimals: 1,
              ),
              _VitalChartCard(
                title: 'Movement',
                unit: 'of 1',
                color: context.ff.brand,
                readings: _readings,
                pick: (r) => r.motionActivity,
                decimals: 2,
              ),
            ],

            const SizedBox(height: FurFeelTokens.space4),
            Text('TAKE IT WITH YOU', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _exporting || _readings.isEmpty ? null : _exportCsv,
                    icon: const Icon(Icons.table_chart_outlined, size: 18),
                    label: const Text('CSV data'),
                  ),
                ),
                const SizedBox(width: FurFeelTokens.space3),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _exporting || _readings.isEmpty ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDF report'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space3),
            OutlinedButton.icon(
              onPressed: _exporting ? null : _exportEverything,
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Download everything (JSON)'),
            ),
            const SizedBox(height: FurFeelTokens.space2),
            Text(
              'The PDF is a friendly summary to share with your vet; the CSV is '
              'the raw data. "Everything" is your complete FurFeel archive for '
              'this dog — readings, stress history, alerts, vet notes, and '
              'observation records. None of it is a medical assessment.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: FurFeelTokens.space5),
          ],
        ),
      ),
    );
  }
}

String _dayLabel(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// Averages the values into at most [maxPoints] evenly spaced buckets.
///
/// Without this the chart plots one spot per reading: 24h of 10-second
/// telemetry is ~8,600 points into ~350 logical pixels, roughly 25 points per
/// pixel, which renders as a solid block of ink rather than a line you can
/// read. Averaging per bucket keeps the shape of the trend while dropping the
/// sampling noise that was filling the card.
///
/// x stays in original reading-index space (the bucket's midpoint), so the
/// x-axis still spans the same range regardless of how much we thinned it.
/// Null values are skipped; a bucket with no readings emits no spot rather
/// than a fake zero (docs/07: missing fields are stored null, never replaced).
List<FlSpot> downsampleToSpots(List<double?> values, {int maxPoints = 96}) {
  if (values.isEmpty) return const [];
  if (values.length <= maxPoints) {
    final out = <FlSpot>[];
    for (final (i, v) in values.indexed) {
      if (v != null) out.add(FlSpot(i.toDouble(), v));
    }
    return out;
  }

  final bucketSize = values.length / maxPoints;
  final out = <FlSpot>[];
  for (var b = 0; b < maxPoints; b++) {
    final start = (b * bucketSize).floor();
    final end = math.min(((b + 1) * bucketSize).ceil(), values.length);
    var sum = 0.0;
    var count = 0;
    for (var i = start; i < end; i++) {
      final v = values[i];
      if (v != null) {
        sum += v;
        count++;
      }
    }
    if (count > 0) out.add(FlSpot((start + end - 1) / 2, sum / count));
  }
  return out;
}

/// Compact endpoint label for the chart's time axis: clock time when the whole
/// range is one day, otherwise the date. Hand-rolled because `intl` isn't a
/// dependency and this is two formats.
String axisTimeLabel(DateTime t, {required bool sameDay}) {
  if (sameDay) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$hour12:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[t.month - 1]} ${t.day}';
}

/// One vital's mini-dashboard: line chart over the range + min/avg/max chips.
class _VitalChartCard extends StatelessWidget {
  const _VitalChartCard({
    required this.title,
    required this.unit,
    required this.color,
    required this.readings,
    required this.pick,
    this.decimals = 0,
  });

  final String title;
  final String unit;
  final Color color;
  final List<TelemetryReading> readings;
  final double? Function(TelemetryReading) pick;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Thin the series before charting -- see downsampleToSpots for why.
    final spots = downsampleToSpots([for (final r in readings) pick(r)]);
    final summary = vitalSummary(readings, pick);

    return Card(
      margin: const EdgeInsets.only(bottom: FurFeelTokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: FurFeelTokens.space2),
                Expanded(
                  child: Text('$title ($unit)',
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space3),
            if (spots.length < 2 || summary == null)
              Text('Not enough data in this period', style: textTheme.bodySmall)
            else ...[
              _BaselineChart(
                spots: spots,
                color: color,
                summary: summary,
                decimals: decimals,
              ),
              const SizedBox(height: FurFeelTokens.space2),
              _TimeAxis(readings: readings),
            ],
            if (summary != null) ...[
              const SizedBox(height: FurFeelTokens.space3),
              Wrap(
                spacing: FurFeelTokens.space4,
                runSpacing: FurFeelTokens.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // The two-tone fill needs naming -- shading alone never
                  // carries meaning (docs/19: word + swatch, not color alone).
                  _SwatchChip(color: color.withValues(alpha: 0.28), label: 'Above average'),
                  _SwatchChip(
                    color: context.ff.inkMuted.withValues(alpha: 0.16),
                    label: 'Below average',
                  ),
                  _StatChip(label: 'Low', value: summary.min.toStringAsFixed(decimals)),
                  _StatChip(
                      label: 'Average', value: summary.avg.toStringAsFixed(decimals)),
                  _StatChip(label: 'High', value: summary.max.toStringAsFixed(decimals)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Baseline chart (TradingView's "baseline" technique): one dashed reference
/// line at this period's average, with the area between the line and that
/// baseline shaded in two tones — one for the stretches running above average,
/// another for below. That single reference is what turns a squiggle into a
/// readable answer to "is this high or low *for this dog*", which a bare line
/// with no baseline never answered.
///
/// Deliberately NOT green-above/red-below like a stock chart: above average
/// isn't "bad" here (a dog that just played has a high heart rate and is
/// perfectly fine), so the fills stay the vital's own hue vs. a neutral grey.
/// Judging a reading is the classifier's job, not this chart's (CLAUDE.md:
/// decision support, never diagnosis).
class _BaselineChart extends StatelessWidget {
  const _BaselineChart({
    required this.spots,
    required this.color,
    required this.summary,
    required this.decimals,
  });

  final List<FlSpot> spots;
  final Color color;
  final ({double min, double avg, double max}) summary;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    // Headroom so the line and its fill never touch the card edges. Scaled to
    // the value's own precision, so 0-1 motion and 3-digit bpm both breathe.
    final step = math.pow(10, -decimals).toDouble();
    final pad = math.max((summary.max - summary.min) * 0.18, step * 2);
    final baseline = summary.avg;

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minY: summary.min - pad,
          maxY: summary.max + pad,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: color,
              barWidth: 2,
              isCurved: true,
              preventCurveOverShooting: true,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              // fl_chart names these by which side of the LINE they fill, so
              // clipping both at the baseline gives the two-tone split:
              // "below the line, down to the average" = the above-average
              // stretches, and vice versa. Naming reads backwards; the render
              // is right.
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.28),
                applyCutOffY: true,
                cutOffY: baseline,
              ),
              aboveBarData: BarAreaData(
                show: true,
                color: context.ff.inkMuted.withValues(alpha: 0.16),
                applyCutOffY: true,
                cutOffY: baseline,
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: baseline,
                color: context.ff.inkMuted,
                strokeWidth: 1,
                dashArray: const [4, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(bottom: 2),
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeCaptionSize,
                    fontWeight: FontWeight.w600,
                    color: context.ff.inkMuted,
                  ),
                  labelResolver: (_) => 'avg ${baseline.toStringAsFixed(decimals)}',
                ),
              ),
            ],
          ),
          // Grid lines would compete with the baseline for attention; the
          // baseline IS the reference now, so the grid goes.
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
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
    );
  }
}

/// Start/end timestamps under a chart — without them the x-axis is unlabelled
/// and there's no way to tell what period you're looking at.
class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.readings});

  final List<TelemetryReading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();
    final first = readings.first.capturedAt;
    final last = readings.last.capturedAt;
    final sameDay =
        first.year == last.year && first.month == last.month && first.day == last.day;
    final style = TextStyle(
      fontSize: FurFeelTokens.typeCaptionSize,
      color: context.ff.inkMuted,
    );
    return Padding(
      // Clear the y-axis labels so the start time sits over the plot area.
      padding: const EdgeInsets.only(left: 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(axisTimeLabel(first, sameDay: sameDay), style: style),
          Text(axisTimeLabel(last, sameDay: sameDay), style: style),
        ],
      ),
    );
  }
}

/// Legend swatch + word, so the two fill tones are named rather than guessed.
class _SwatchChip extends StatelessWidget {
  const _SwatchChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: FurFeelTokens.space1),
        Text(
          label,
          style: TextStyle(
            fontSize: FurFeelTokens.typeCaptionSize,
            color: context.ff.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: TextStyle(
                fontSize: FurFeelTokens.typeCaptionSize,
                color: context.ff.inkMuted)),
        Text(value,
            style: TextStyle(
              fontSize: FurFeelTokens.typeCaptionSize,
              fontWeight: FontWeight.w700,
              color: context.ff.ink,
            )),
      ],
    );
  }
}
