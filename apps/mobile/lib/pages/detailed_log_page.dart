import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/exports.dart';
import '../util/save_file.dart';

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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong loading the log. Pull to retry.';
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

  Future<void> _export(Future<void> Function() run) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await run();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Export failed — please try again.'),
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
                    style: TextStyle(color: FurFeelTokens.statusHighOwner)),
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
                  color: FurFeelTokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                ),
                child: Text(
                  'No readings in this period — try a wider range.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FurFeelTokens.inkMuted),
                ),
              )
            else ...[
              _VitalChartCard(
                title: 'Heart rate',
                unit: 'bpm',
                color: FurFeelTokens.statusHighOwner,
                readings: _readings,
                pick: (r) => r.heartRateBpm?.toDouble(),
              ),
              _VitalChartCard(
                title: 'Breathing',
                unit: 'breaths/min',
                color: FurFeelTokens.accent,
                readings: _readings,
                pick: (r) => r.respiratoryRateBpm?.toDouble(),
              ),
              _VitalChartCard(
                title: 'Body temperature',
                unit: settings.temperatureUnitLabel,
                color: FurFeelTokens.warm,
                readings: _readings,
                pick: (r) => r.bodyTemperatureC == null
                    ? null
                    : double.parse(settings.formatTemperature(r.bodyTemperatureC)),
                decimals: 1,
              ),
              _VitalChartCard(
                title: 'Movement',
                unit: 'of 1',
                color: FurFeelTokens.brand,
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
            const SizedBox(height: FurFeelTokens.space2),
            Text(
              'The PDF is a friendly summary to share with your vet; the CSV is '
              'the raw data. Neither is a medical assessment.',
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
    final spots = <FlSpot>[];
    for (final (i, r) in readings.indexed) {
      final v = pick(r);
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
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
            if (spots.length < 2)
              Text('Not enough data in this period', style: textTheme.bodySmall)
            else
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        color: color,
                        barWidth: 2,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) =>
                          FlLine(color: FurFeelTokens.hairline, strokeWidth: 1),
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
                              color: FurFeelTokens.inkMuted,
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
            if (summary != null) ...[
              const SizedBox(height: FurFeelTokens.space3),
              Wrap(
                spacing: FurFeelTokens.space4,
                children: [
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
                color: FurFeelTokens.inkMuted)),
        Text(value,
            style: TextStyle(
              fontSize: FurFeelTokens.typeCaptionSize,
              fontWeight: FontWeight.w700,
              color: FurFeelTokens.ink,
            )),
      ],
    );
  }
}
