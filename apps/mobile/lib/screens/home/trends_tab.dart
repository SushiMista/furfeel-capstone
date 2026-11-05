import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/insights/insights.dart';
import 'package:furfeel_mobile/insights/month_summary.dart';
import 'package:furfeel_mobile/insights/owner_moments.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/exports.dart';
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

  @override
  void didUpdateWidget(covariant TrendsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dog.id != widget.dog.id) {
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
    // Tips speak about right now, so they only belong on the current month.
    final tip = !isCurrentMonth
        ? null
        : bestTip(buildInsights(
            dogName: dog.name,
            daily: widget.daily,
            hourly: widget.hourly,
            alerts: widget.alerts,
            now: now,
          ));
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
          if (tip != null && days != null) ...[
            SizedBox(height: 16 * scale),
            _TipNote(tip: tip, scale: scale),
          ],
          SizedBox(height: 10 * scale),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.ios_share,
                  label: _sharing ? 'Building…' : 'Share report',
                  scale: scale,
                  onTap: hasData && !_sharing ? _shareWeeklyReport : null,
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: _ActionButton(
                  icon: Icons.format_list_bulleted,
                  label: 'All readings',
                  scale: scale,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DetailedLogPage(
                        repository: widget.repository,
                        dog: dog,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          Text(
            'Trends support your care decisions, not a diagnosis.',
            textAlign: TextAlign.center,
            style: _type(context, 11.5 * scale, color: context.ff.inkMuted),
          ),
        ],
      ),
    );
  }
}

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

class _TipNote extends StatelessWidget {
  const _TipNote({required this.tip, required this.scale});

  final Insight tip;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 13 * scale,
        vertical: 11 * scale,
      ),
      decoration: BoxDecoration(
        color: context.ff.brandSoft,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Text.rich(
        TextSpan(
          text: tip.tipLead,
          style: const TextStyle(fontWeight: FontWeight.w600),
          children: [
            TextSpan(
              text: tip.tipRest,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ],
        ),
        style: _type(context, 13.5 * scale, height: 1.4),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.scale,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? context.ff.inkMuted : context.ff.brand;
    return Material(
      color: context.ff.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13 * scale),
        side: BorderSide(color: context.ff.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: FurFeelTokens.touchTargetMin,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16 * scale, color: color),
              SizedBox(width: 6 * scale),
              Text(
                label,
                style: _type(
                  context,
                  13 * scale,
                  weight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
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
          ],
        ),
      ),
    );
  }
}
