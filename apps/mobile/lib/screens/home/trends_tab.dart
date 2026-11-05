import 'package:flutter/material.dart';
<<<<<<< HEAD

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/insights/insights.dart';
=======
import 'package:flutter_animate/flutter_animate.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/insights/insights.dart';
import 'package:furfeel_mobile/insights/month_summary.dart';
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
import 'package:furfeel_mobile/insights/owner_moments.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/exports.dart';
<<<<<<< HEAD
import 'package:furfeel_mobile/util/save_file.dart';
import 'package:furfeel_mobile/widgets/stress_mix_chart.dart';
import 'package:furfeel_mobile/widgets/section_header.dart';
import 'package:furfeel_mobile/widgets/wellness_card.dart';
import 'package:furfeel_mobile/screens/vitals/detailed_log_page.dart';

/// Trends tab: the owner's "is it getting better, and what helps?" screen.
/// Headline stat + one composition chart + computed insight cards — raw logs
/// live one tap away in the detailed log (docs/04: simple visualizations for
/// non-technical owners; docs/19 §6: one or two series, no chartjunk).
/// QA: the chart range is adjustable (7/14/30 days — historical view), and a
/// one-line week story sits with the chart.
=======
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/util/save_file.dart';
import 'package:furfeel_mobile/widgets/alert_card.dart';
import 'package:furfeel_mobile/widgets/day_timeline.dart';
import 'package:furfeel_mobile/widgets/dog_avatar.dart';
import 'package:furfeel_mobile/widgets/stress_calendar.dart';
import 'package:furfeel_mobile/widgets/stress_pill.dart';
import 'package:furfeel_mobile/screens/home/chat_tab.dart';
import 'package:furfeel_mobile/screens/vitals/detailed_log_page.dart';

/// Trends tab: answers four things an owner actually asks, top to bottom. How
/// has my dog been, which days stood out, what should I know, and what can I do
/// with this. Raw logs stay one tap away (docs/04, docs/19 §6).
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
class TrendsTab extends StatefulWidget {
  const TrendsTab({
    super.key,
    required this.repository,
    required this.dog,
    required this.daily,
    required this.hourly,
    required this.alerts,
    required this.onRefresh,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final List<DailyStressSummary> daily;
  final List<HourlyStressBucket> hourly;
  final List<Alert> alerts;
  final Future<void> Function() onRefresh;

  @override
  State<TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<TrendsTab> {
<<<<<<< HEAD
  int _days = 14;
  bool _sharing = false;

  /// Range-specific summaries; null = use the shell's default 14-day data.
  List<DailyStressSummary>? _rangeDaily;
  bool _rangeLoading = false;

  List<DailyStressSummary> get _daily => _rangeDaily ?? widget.daily;
=======
  /// How far back the month arrows go.
  static const _monthsBack = 12;
  static const _historyDays = 60;

  bool _sharing = false;
  late DateTime _month = _monthOf(DateTime.now());
  List<DailyStressSummary>? _days;
  bool _hasEarlierData = false;
  int _loadRun = 0;

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9

  @override
  void didUpdateWidget(covariant TrendsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dog.id != widget.dog.id) {
<<<<<<< HEAD
      setState(() {
        _days = 14;
        _rangeDaily = null;
      });
    }
  }

  Future<void> _setDays(int days) async {
    setState(() {
      _days = days;
      _rangeLoading = days != 14;
      if (days == 14) _rangeDaily = null;
    });
    if (days == 14) return;
    try {
      final rows =
          await widget.repository.fetchDailyStressSummary(widget.dog.id, days: days);
      if (!mounted || _days != days) return;
      setState(() {
        _rangeDaily = rows;
        _rangeLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _rangeLoading = false);
    }
  }

=======
      _month = _monthOf(DateTime.now());
      _days = null;
      _loadMonth();
    } else if (!identical(oldWidget.daily, widget.daily)) {
      _loadMonth();
    }
  }

  Future<void> _loadMonth() async {
    final run = ++_loadRun;
    final month = _month;
    final now = DateTime.now();
    try {
      final rows = await widget.repository.fetchDailyStressSummary(
        widget.dog.id,
        // A little past the month's start, to tell a new dog from an old one.
        days: now.difference(month).inDays + 1 + _historyDays,
      );
      if (!mounted || run != _loadRun) return;
      setState(() {
        _days = rows
            .where((d) => d.day.year == month.year && d.day.month == month.month)
            .toList();
        _hasEarlierData = rows.any((d) => d.total > 0 && d.day.isBefore(month));
      });
    } catch (_) {
      if (mounted && run == _loadRun) setState(() => _days = const []);
    }
  }

  void _changeMonth(int by) {
    setState(() {
      _month = DateTime(_month.year, _month.month + by);
      _days = null;
    });
    _loadMonth();
  }

  void _openDay(DateTime date, DailyStressSummary? summary) {
    final alerts = widget.alerts
        .where((a) => DateUtils.isSameDay(a.createdAt, date))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.ff.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (_) => _DayPanel(
        repository: widget.repository,
        dog: widget.dog,
        date: date,
        level: summary == null ? null : dayLevel(summary),
        alerts: alerts,
      ),
    );
  }

>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
  /// One-tap weekly PDF report (owner-delight pass): last 7 days, straight to
  /// the share sheet / browser download. Reuses the detailed-log exporter.
  Future<void> _shareWeeklyReport() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 7));
    try {
      final results = await Future.wait<Object>([
        widget.repository.fetchReadingsBetween(widget.dog.id, from, to),
        widget.repository.fetchClassificationsBetween(widget.dog.id, from, to),
        // Owner + clinic details make the PDF a transferable record
        // (owner feedback): another clinic can file it as-is.
        widget.repository.fetchMyProfile(),
        widget.repository.fetchClinics(),
      ]);
      Clinic? clinic;
      for (final c in results[3] as List<Clinic>) {
        if (c.id == widget.dog.clinicId) clinic = c;
      }
      final bytes = await buildHealthReportPdf(
        dog: widget.dog,
        from: from,
        to: to,
        readings: results[0] as List<TelemetryReading>,
        classifications: results[1] as List<StressClassification>,
        owner: results[2] as UserProfile,
        clinic: clinic,
        alerts: widget.alerts,
      );
      final name =
          widget.dog.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      await saveOrShareFile(
          bytes, 'furfeel-$name-weekly.pdf', 'application/pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn\'t build the report — please try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dog = widget.dog;
<<<<<<< HEAD
    final repository = widget.repository;
    final onRefresh = widget.onRefresh;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final week = weekOverWeekCalm(widget.daily, now);
    final insights = buildInsights(
=======
    final now = DateTime.now();
    final days = _days;
    final scale = _scaleOf(context);
    final byDay = {for (final d in days ?? const <DailyStressSummary>[]) d.day.day: d};
    final monthAlerts = widget.alerts.where(
      (a) =>
          a.createdAt.year == _month.year && a.createdAt.month == _month.month,
    );
    final summary = monthSummary(
      dogName: dog.name,
      month: _month,
      days: days ?? const [],
      alertCount: monthAlerts.length,
      calmRun: calmStreak(widget.daily, now),
      now: now,
      hasEarlierData: _hasEarlierData,
    );
    final isCurrentMonth = _month == _monthOf(now);
    final earliest = DateTime(now.year, now.month - _monthsBack);
    // These speak about right now, so they only belong on the current month.
    // Patterns beat week-over-week: the headline already covers how it went.
    final notes = !isCurrentMonth ? const <Insight>[] : buildInsights(
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
      dogName: dog.name,
      daily: widget.daily,
      hourly: widget.hourly,
      alerts: widget.alerts,
      now: now,
<<<<<<< HEAD
    );
    final story = weekStory(dog.name, widget.daily, now);
    final hasData = widget.daily.any((d) => d.total > 0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          if (!hasData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(FurFeelTokens.space6),
              decoration: BoxDecoration(
                color: context.ff.surfaceAlt,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
              ),
              child: Column(
                children: [
                  Icon(Icons.insights_outlined, size: 40, color: context.ff.brand),
                  const SizedBox(height: FurFeelTokens.space3),
                  Text(
                    'Trends appear after a day or two of wearing the harness — '
                    'then you\'ll see what helps ${dog.name} feel their best.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else ...[
            _CalmWeekHero(dogName: dog.name, week: week),
            const SizedBox(height: FurFeelTokens.space3),
            // Owner-delight pass: celebrate a run of mostly-calm days.
            if (calmStreak(widget.daily, now) >= 2) ...[
              _StreakCard(dogName: dog.name, days: calmStreak(widget.daily, now)),
              const SizedBox(height: FurFeelTokens.space3),
            ],
            // QA item 16: today's wellness score + activity/rest balance.
            WellnessCard(repository: repository, dog: dog),
            const SizedBox(height: FurFeelTokens.space5),
            Row(
              children: [
                Expanded(child: Text('Stress history', style: TextStyle(fontSize: FurFeelTokens.typeH3Size, fontWeight: FontWeight.w800, color: context.ff.ink))),
                // QA: adjustable historical window.
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7d')),
                    ButtonSegment(value: 14, label: Text('14d')),
                    ButtonSegment(value: 30, label: Text('30d')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (selection) => _setDays(selection.first),
                ),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space2),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(FurFeelTokens.space4),
                child: _rangeLoading
                    ? const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : StressMixChart(daily: _daily),
              ),
            ),
            if (story != null) ...[
              const SizedBox(height: FurFeelTokens.space2),
              Text(story, style: textTheme.bodySmall),
            ],
            const SizedBox(height: FurFeelTokens.space5),
            SectionHeader(title: 'What seems to help'),
            const SizedBox(height: FurFeelTokens.space2),
            if (insights.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(FurFeelTokens.space5),
                decoration: BoxDecoration(
                  color: context.ff.surfaceAlt,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                ),
                child: Text(
                  'Still learning ${dog.name}\'s patterns — insights show up '
                  'once there\'s enough data to be honest about them',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.ff.inkMuted),
                ),
              )
            else
              for (final insight in insights) _InsightCard(insight: insight),
          ],
          const SizedBox(height: FurFeelTokens.space4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DetailedLogPage(repository: repository, dog: dog),
                  ),
                ),
                icon: const Icon(Icons.list_alt_outlined, size: 18),
                label: const Text('View detailed log'),
              ),
              const SizedBox(width: FurFeelTokens.space2),
              TextButton.icon(
                onPressed: hasData && !_sharing ? _shareWeeklyReport : null,
                icon: const Icon(Icons.ios_share_outlined, size: 18),
                label: Text(_sharing ? 'Building…' : 'Share weekly report'),
              ),
            ],
          ),
          const SizedBox(height: FurFeelTokens.space2),
          Text(
            'Trends support your care decisions — they are not a diagnosis.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
=======
    ).where((i) => i.kind != InsightKind.weeklyTrend).take(2).toList();
    final hasData = widget.daily.any((d) => d.total > 0);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20 * scale,
          8 * scale,
          20 * scale,
          FurFeelTokens.space6,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: days == null
                    ? _HeadlineSkeleton(key: _loadingKey, scale: scale)
                    : Text(
                        summary.headline,
                        style: _type(
                          context,
                          29 * scale,
                          weight: FontWeight.w700,
                          height: 1.08,
                          tracking: -0.025 * 29 * scale,
                        ),
                      ),
              ),
              SizedBox(width: 14 * scale),
              DogAvatar(
                dog: dog,
                repository: widget.repository,
                radius: 43 * scale,
                cornerRadius: 26 * scale,
                shape: DogAvatarShape.squircle,
              ),
            ],
          ),
          SizedBox(height: 12 * scale),
          if (days == null)
            _SkeletonBar(width: 240 * scale, height: 14 * scale)
          else
            Text(
              summary.lede,
              style: _type(
                context,
                14 * scale,
                height: 1.45,
                color: context.ff.ink.withValues(alpha: 0.82),
              ),
            ),
          SizedBox(height: 18 * scale),
          Row(
            children: [
              _MonthArrow(
                label: 'Previous month',
                icon: Icons.chevron_left,
                alignment: Alignment.centerLeft,
                scale: scale,
                onTap: _month.isAfter(earliest) ? () => _changeMonth(-1) : null,
              ),
              Text(
                monthName(_month) +
                    (_month.year == now.year ? '' : ' ${_month.year}'),
                style: _type(context, 15 * scale, weight: FontWeight.w600),
              ),
              _MonthArrow(
                label: 'Next month',
                icon: Icons.chevron_right,
                alignment: Alignment.center,
                scale: scale,
                onTap: isCurrentMonth ? null : () => _changeMonth(1),
              ),
            ],
          ),
          StressCalendar(
            month: _month,
            levels: {
              for (final entry in byDay.entries)
                entry.key: dayLevel(entry.value),
            },
            alertDays: {for (final a in monthAlerts) a.createdAt.day},
            now: now,
            scale: scale,
            loading: days == null,
            onDayTap: (date) => _openDay(date, byDay[date.day]),
          ),
          SizedBox(height: 5 * scale),
          _CalendarKey(scale: scale),
          if (notes.isNotEmpty) ...[
            SizedBox(height: 20 * scale),
            Text(
              'Worth knowing',
              style: _type(context, 15 * scale, weight: FontWeight.w600),
            ),
            SizedBox(height: 4 * scale),
            for (final (i, note) in notes.indexed)
              Container(
                padding: EdgeInsets.symmetric(vertical: 9 * scale),
                decoration: BoxDecoration(
                  border: i == notes.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: context.ff.hairline)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: _type(context, 13.5 * scale, weight: FontWeight.w600),
                    ),
                    Text(
                      note.body,
                      style: _type(
                        context,
                        12.5 * scale,
                        height: 1.4,
                        color: context.ff.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          SizedBox(height: 6 * scale),
          Row(
            children: [
              _TextLink(
                label: _sharing ? 'Building…' : 'Share a report',
                scale: scale,
                onTap: hasData && !_sharing ? _shareWeeklyReport : null,
              ),
              SizedBox(width: 18 * scale),
              _TextLink(
                label: 'All readings',
                scale: scale,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DetailedLogPage(repository: widget.repository, dog: dog),
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Trends support your care decisions, not a diagnosis.',
            style: _type(context, 11.5 * scale, color: context.ff.inkMuted),
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
          ),
        ],
      ),
    );
  }
}

<<<<<<< HEAD
/// Calm-streak celebration (owner-delight pass). Observational: it counts
/// mostly-calm days, it doesn't explain them.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.dogName, required this.days});

  final String dogName;
  final int days;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      decoration: BoxDecoration(
        color: context.ff.warmSoft,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 24)),
          const SizedBox(width: FurFeelTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$days mostly-calm days in a row',
                  style:
                      textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Whatever you\'re doing, $dogName seems settled — keep it up.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Headline stat tile: calm share this week + week-over-week direction.
class _CalmWeekHero extends StatelessWidget {
  const _CalmWeekHero({required this.dogName, required this.week});

  final String dogName;
  final ({double? current, double? previous}) week;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final current = week.current;
    final previous = week.previous;
    final delta = (current != null && previous != null) ? current - previous : null;

    final (deltaText, deltaColor, deltaIcon) = switch (delta) {
      null => (null, context.ff.inkMuted, null),
      >= 0.05 => (
          '+${(delta * 100).round()} pts vs last week',
          context.ff.statusCalmFg,
          Icons.trending_up,
        ),
      <= -0.05 => (
          '${(delta * 100).round()} pts vs last week',
          context.ff.warm,
          Icons.trending_down,
        ),
      _ => ('about the same as last week', context.ff.inkMuted, Icons.trending_flat),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'Calm time this week'),
            const SizedBox(height: FurFeelTokens.space2),
            Text(
              current == null ? '—' : '${(current * 100).round()}%',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: context.ff.ink,
                height: 1.1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (deltaText != null) ...[
              const SizedBox(height: FurFeelTokens.space1),
              Row(
                children: [
                  if (deltaIcon != null) Icon(deltaIcon, size: 16, color: deltaColor),
                  const SizedBox(width: FurFeelTokens.space1),
                  Text(
                    deltaText,
                    style: TextStyle(
                      fontSize: FurFeelTokens.typeCaptionSize,
                      fontWeight: FontWeight.w600,
                      color: deltaColor,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: FurFeelTokens.space1),
              Text('of the time $dogName wore the harness', style: textTheme.bodySmall),
            ],
=======
const _loadingKey = ValueKey('trends-loading');

/// The page is drawn to a 340pt design, so it scales with the phone's width.
double _scaleOf(BuildContext context) =>
    (MediaQuery.sizeOf(context).width / 340).clamp(0.94, 1.2);

/// This page's type is set directly: the theme's body text adds letter spacing
/// that loosens these short lines.
TextStyle _type(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
  double height = 1.3,
  double tracking = 0,
  Color? color,
}) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: tracking,
          color: color ?? context.ff.ink,
        );

/// Same shimmer as the Home skeleton (docs/19 §5a).
class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.ff.surfaceAlt,
        borderRadius: BorderRadius.circular(height / 3),
      ),
    );
    if (context.reduceMotion) return bar;
    return bar
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: context.ff.surface);
  }
}

class _HeadlineSkeleton extends StatelessWidget {
  const _HeadlineSkeleton({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading trends',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBar(width: 190 * scale, height: 26 * scale),
          SizedBox(height: 8 * scale),
          _SkeletonBar(width: 130 * scale, height: 26 * scale),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.label,
    required this.icon,
    required this.alignment,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Alignment alignment;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 32 * scale,
            height: 44,
            child: Align(
              alignment: alignment,
              child: Icon(
                icon,
                size: 20 * scale,
                color: context.ff.inkMuted
                    .withValues(alpha: onTap == null ? 0.35 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.scale, this.onTap});

  final String label;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: _type(
              context,
              13 * scale,
              weight: FontWeight.w600,
              color: onTap == null ? context.ff.inkMuted : context.ff.brand,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarKey extends StatelessWidget {
  const _CalendarKey({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = _type(context, 11 * scale, color: context.ff.inkMuted);
    return Wrap(
      spacing: 11 * scale,
      runSpacing: FurFeelTokens.space1,
      children: [
        for (final level in StressLevel.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8 * scale,
                height: 8 * scale,
                decoration: BoxDecoration(
                  color: stressLevelChartFill(context, level),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 4 * scale),
              Text(
                level.name[0].toUpperCase() + level.name.substring(1),
                style: style,
              ),
            ],
          ),
        Text('• Alert', style: style),
      ],
    );
  }
}

/// "5 PM", in the day panel's plainer style.
String _clock(int hour) {
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h ${hour < 12 ? 'AM' : 'PM'}';
}

/// One day, hour by hour, with the one thing an owner can do about it.
class _DayPanel extends StatefulWidget {
  const _DayPanel({
    required this.repository,
    required this.dog,
    required this.date,
    required this.level,
    required this.alerts,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final DateTime date;
  final StressLevel? level;
  final List<Alert> alerts;

  @override
  State<_DayPanel> createState() => _DayPanelState();
}

class _DayPanelState extends State<_DayPanel> {
  List<StressLevel?>? _hours;
  int? _selectedHour;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.level == null) return;
    final start = widget.date;
    final end = DateTime(start.year, start.month, start.day + 1);
    try {
      final rows = await widget.repository
          .fetchClassificationsBetween(widget.dog.id, start, end);
      if (mounted) setState(() => _hours = hourlyDominantLevels(rows, start));
    } catch (_) {
      // The word and alerts still describe the day without the strip.
    }
  }

  Widget _fact(BuildContext context, double scale, InlineSpan text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8 * scale),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.ff.hairline)),
      ),
      child: Text.rich(text, style: _type(context, 13.5 * scale)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _scaleOf(context);
    final date = widget.date;
    final level = widget.level;
    final hours = _hours;
    final hardest = hours == null ? null : hardestHour(hours);
    final alerts = widget.alerts;
    // A flaky harness can raise the same alert many times in a day.
    final alertCounts = <String, int>{};
    for (final alert in alerts) {
      final text = alertHeadline(alert.type) ?? alert.message;
      alertCounts[text] = (alertCounts[text] ?? 0) + 1;
    }
    final now = DateTime.now();
    final full = MaterialLocalizations.of(context).formatFullDate(date);
    final title = full.substring(0, full.lastIndexOf(','));
    final sameDay = DateUtils.isSameDay(date, now);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20 * scale,
          10 * scale,
          20 * scale,
          18 * scale,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.ff.hairline,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
                ),
              ),
            ),
            SizedBox(height: 14 * scale),
            Text(
              title,
              style: _type(
                context,
                20 * scale,
                weight: FontWeight.w700,
                tracking: -0.02 * 20 * scale,
              ),
            ),
            SizedBox(height: 3 * scale),
            Text(
              dayWord(level),
              style: _type(
                context,
                13.5 * scale,
                weight: FontWeight.w600,
                color: level == null
                    ? context.ff.inkMuted
                    : stressLevelColor(context, level),
              ),
            ),
            SizedBox(height: 14 * scale),
            if (hours != null) ...[
              if (_selectedHour != null) ...[
                HourReadout(hour: _selectedHour, hours: hours),
                const SizedBox(height: FurFeelTokens.space2),
              ],
              HourStrip(
                hours: hours,
                lastHour: sameDay ? now.hour : 23,
                selectedHour: _selectedHour,
                onSelect: (hour) => setState(
                  () => _selectedHour = _selectedHour == hour ? null : hour,
                ),
              ),
              SizedBox(height: 5 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final hour in const [0, 6, 12, 18, 0])
                    Text(
                      _clock(hour),
                      style: _type(
                        context,
                        10.5 * scale,
                        color: context.ff.inkMuted,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 14 * scale),
            ],
            if (hardest != null)
              _fact(
                context,
                scale,
                TextSpan(text: 'Hardest around ${_clock(hardest)}'),
              ),
            for (final entry in alertCounts.entries)
              _fact(
                context,
                scale,
                TextSpan(
                  text: '${entry.value} ${entry.value == 1 ? 'alert' : 'alerts'}',
                  children: [
                    TextSpan(
                      text: ' · ${entry.key}',
                      style: TextStyle(color: context.ff.inkMuted),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 8 * scale),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.ff.brand,
                  padding: EdgeInsets.symmetric(vertical: 12 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13 * scale),
                  ),
                ),
                onPressed: () {
                  final navigator = Navigator.of(context)..pop();
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) => DogChatPage(
                        repository: widget.repository,
                        dog: widget.dog,
                        alert: alerts.firstOrNull,
                        draft: 'About $title: ',
                      ),
                    ),
                  );
                },
                child: Text(
                  'Message vet about this day',
                  style: _type(
                    context,
                    14 * scale,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
          ],
        ),
      ),
    );
  }
}
<<<<<<< HEAD

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (bg, fg, icon) = switch (insight.tone) {
      InsightTone.positive => (
          context.ff.statusCalmBg,
          context.ff.statusCalmFg,
          Icons.favorite_outline,
        ),
      InsightTone.attention => (
          context.ff.warmSoft,
          context.ff.warm,
          Icons.lightbulb_outline,
        ),
      InsightTone.neutral => (
          context.ff.brandSoft,
          context.ff.brand,
          Icons.insights_outlined,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: FurFeelTokens.space3),
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      decoration: BoxDecoration(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        border: Border.all(color: context.ff.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(FurFeelTokens.space2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
            ),
            child: Icon(icon, size: 18, color: fg),
          ),
          const SizedBox(width: FurFeelTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: textTheme.titleMedium),
                const SizedBox(height: FurFeelTokens.space1),
                Text(insight.body, style: textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
=======
>>>>>>> 20e52663b2b04379741610740390fdb8af7f9fb9
