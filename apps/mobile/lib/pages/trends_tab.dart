import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../insights/insights.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../widgets/stress_mix_chart.dart';
import '../widgets/wellness_card.dart';
import 'detailed_log_page.dart';

/// Trends tab: the owner's "is it getting better, and what helps?" screen.
/// Headline stat + one composition chart + computed insight cards — raw logs
/// live one tap away in the detailed log (docs/04: simple visualizations for
/// non-technical owners; docs/19 §6: one or two series, no chartjunk).
/// QA: the chart range is adjustable (7/14/30 days — historical view), and a
/// one-line week story sits with the chart.
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
  int _days = 14;

  /// Range-specific summaries; null = use the shell's default 14-day data.
  List<DailyStressSummary>? _rangeDaily;
  bool _rangeLoading = false;

  List<DailyStressSummary> get _daily => _rangeDaily ?? widget.daily;

  @override
  void didUpdateWidget(covariant TrendsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dog.id != widget.dog.id) {
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

  @override
  Widget build(BuildContext context) {
    final dog = widget.dog;
    final repository = widget.repository;
    final onRefresh = widget.onRefresh;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final week = weekOverWeekCalm(widget.daily, now);
    final insights = buildInsights(
      dogName: dog.name,
      daily: widget.daily,
      hourly: widget.hourly,
      alerts: widget.alerts,
      now: now,
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
                color: FurFeelTokens.surfaceAlt,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
              ),
              child: Column(
                children: [
                  Icon(Icons.insights_outlined, size: 40, color: FurFeelTokens.brand),
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
            // QA item 16: today's wellness score + activity/rest balance.
            WellnessCard(repository: repository, dog: dog),
            const SizedBox(height: FurFeelTokens.space5),
            Row(
              children: [
                Expanded(child: Text('STRESS HISTORY', style: textTheme.labelSmall)),
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
            Text('WHAT SEEMS TO HELP', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            if (insights.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(FurFeelTokens.space5),
                decoration: BoxDecoration(
                  color: FurFeelTokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                ),
                child: Text(
                  'Still learning ${dog.name}\'s patterns — insights show up '
                  'once there\'s enough data to be honest about them',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FurFeelTokens.inkMuted),
                ),
              )
            else
              for (final insight in insights) _InsightCard(insight: insight),
          ],
          const SizedBox(height: FurFeelTokens.space4),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DetailedLogPage(repository: repository, dog: dog),
                ),
              ),
              icon: const Icon(Icons.list_alt_outlined, size: 18),
              label: const Text('View detailed log'),
            ),
          ),
          const SizedBox(height: FurFeelTokens.space2),
          Text(
            'Trends support your care decisions — they are not a diagnosis.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
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
      null => (null, FurFeelTokens.inkMuted, null),
      >= 0.05 => (
          '+${(delta * 100).round()} pts vs last week',
          FurFeelTokens.statusCalmFg,
          Icons.trending_up,
        ),
      <= -0.05 => (
          '${(delta * 100).round()} pts vs last week',
          FurFeelTokens.warm,
          Icons.trending_down,
        ),
      _ => ('about the same as last week', FurFeelTokens.inkMuted, Icons.trending_flat),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CALM TIME THIS WEEK', style: textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            Text(
              current == null ? '—' : '${(current * 100).round()}%',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: FurFeelTokens.ink,
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
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (bg, fg, icon) = switch (insight.tone) {
      InsightTone.positive => (
          FurFeelTokens.statusCalmBg,
          FurFeelTokens.statusCalmFg,
          Icons.favorite_outline,
        ),
      InsightTone.attention => (
          FurFeelTokens.warmSoft,
          FurFeelTokens.warm,
          Icons.lightbulb_outline,
        ),
      InsightTone.neutral => (
          FurFeelTokens.brandSoft,
          FurFeelTokens.brand,
          Icons.insights_outlined,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: FurFeelTokens.space3),
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      decoration: BoxDecoration(
        color: FurFeelTokens.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        border: Border.all(color: FurFeelTokens.hairline),
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
