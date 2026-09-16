import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/insights/biometrics.dart';
import 'package:furfeel_mobile/models/activity_state.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/day_timeline.dart';
import 'package:furfeel_mobile/widgets/curved_status_header.dart';
import 'package:furfeel_mobile/widgets/section_header.dart';
import 'package:furfeel_mobile/widgets/wave_sparkline.dart';
import 'package:furfeel_mobile/screens/vitals/vital_detail_page.dart';

/// Finds the daily summary for one calendar day, or null when there's none.
DailyStressSummary? _summaryForDay(List<DailyStressSummary> daily, DateTime day) {
  for (final d in daily) {
    if (d.day.year == day.year && d.day.month == day.month && d.day.day == day.day) {
      return d;
    }
  }
  return null;
}

/// Owner home (docs/04 module 1): "how is my dog right now, and what should I
/// do?" — status hero, today-so-far calm stat, care insights for the current
/// stress level, and quick links. Raw readings live in the detailed log; a
/// glance here should answer the question without scrolling a sensor feed.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.repository,
    required this.dog,
    required this.reading,
    required this.classification,
    required this.daily,
    required this.device,
    required this.guidance,
    required this.onRefresh,
    required this.dogsCount,
    required this.alerts,
    this.onBack,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final TelemetryReading? reading;
  final StressClassification? classification;
  final List<DailyStressSummary> daily;
  final Device? device;
  final List<CareGuidance> guidance;
  final Future<void> Function() onRefresh;

  /// Total dogs on this account and this dog's own alerts — both already
  /// loaded by RootShell, just plumbed through for the overview card below.
  final int dogsCount;
  final List<Alert> alerts;

  /// When set, the hero's top-left button is a back arrow (this Home is pushed,
  /// e.g. a dog-detail screen). When null it shows the decorative paw.
  final VoidCallback? onBack;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  Widget build(BuildContext context) {
    final level = widget.classification?.stressLevel;
    // Combination-aware tip (QA item 11): cold+stressed, hot+stressed,
    // restless+high HR... each gets tailored advice; falls back to the
    // per-level guidance when no combination applies.
    final careGuidance = selectGuidance(
      widget.guidance,
      level: level,
      contextKey: careContextKey(level: level, reading: widget.reading),
      clinicId: widget.dog.clinicId,
    );

    final bottom = MediaQuery.paddingOf(context).bottom;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          // Immersive full-bleed status hero (docs/22 v7): the classification
          // as the hero, on a status-coloured top with a curved divider.
          _ImmersiveHero(
            dog: widget.dog,
            level: level,
            openAlerts: widget.alerts.where((a) => a.status == 'open').length,
            hasCareTip: careGuidance != null,
            onBack: widget.onBack,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(FurFeelTokens.space4,
                FurFeelTokens.space3, FurFeelTokens.space4, FurFeelTokens.space6 + bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.dog.isBirthday(DateTime.now())) ...[
                  _BirthdayBanner(dog: widget.dog).entrance(context),
                  const SizedBox(height: FurFeelTokens.space3),
                ],
                // Health overview — one waveform row per vital, each its own
                // colour, opening a detail screen (docs/22 v7, ADR-024).
                const SectionHeader(title: 'Health overview', hint: 'Last 7 days'),
                const SizedBox(height: FurFeelTokens.space3),
                _VitalGrid(
                  repository: widget.repository,
                  dog: widget.dog,
                  reading: widget.reading,
                ).entrance(context, index: 1),
                if (careGuidance != null) ...[
                  const SizedBox(height: FurFeelTokens.space5),
                  const SectionHeader(title: 'Care'),
                  const SizedBox(height: FurFeelTokens.space3),
                  _CareInsightsCard(guidance: careGuidance).entrance(context, index: 2),
                ],
                const SizedBox(height: FurFeelTokens.space5),
                const SectionHeader(title: 'Activity'),
                const SizedBox(height: FurFeelTokens.space3),
                _TodaySoFar(daily: widget.daily).entrance(context, index: 3),
                const SizedBox(height: FurFeelTokens.space3),
                DayTimeline(repository: widget.repository, dog: widget.dog)
                    .entrance(context, index: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The immersive status hero: FurFeel-score classification on a status-coloured
/// full-bleed top with the curved divider (docs/22 v7).
class _ImmersiveHero extends StatelessWidget {
  const _ImmersiveHero({
    required this.dog,
    required this.level,
    required this.openAlerts,
    required this.hasCareTip,
    this.onBack,
  });

  final Dog dog;
  final StressLevel? level;
  final int openAlerts;
  final bool hasCareTip;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final color = switch (level) {
      StressLevel.calm => p.statusCalmFg,
      StressLevel.mild => p.statusMildFg,
      StressLevel.moderate => p.statusModerateFg,
      StressLevel.high => p.statusHighFg,
      null => p.brand,
    };
    final word = level == null
        ? 'No data'
        : level!.name[0].toUpperCase() + level!.name.substring(1);
    final description =
        level == null ? 'Waiting for the first reading…' : level!.phrase(dog.name);

    return CurvedStatusHeader(
      color: color,
      title: 'FurFeel score',
      mark: Icons.pets,
      value: word,
      description: description,
      leading: onBack == null
          ? const HeaderCircleButton(icon: Icons.pets)
          : HeaderCircleButton(
              icon: Icons.arrow_back_ios_new, tooltip: 'Back', onTap: onBack),
      chips: [
        HeaderChip(
          icon: openAlerts == 0 ? Icons.check : Icons.notifications_active_outlined,
          label: openAlerts == 0 ? 'No alerts' : '$openAlerts alerts',
        ),
        if (hasCareTip)
          const HeaderChip(icon: Icons.auto_awesome, label: '1 care tip'),
      ],
    );
  }
}

/// QA: the four vitals as tappable squares. Each opens a detail screen with
/// the current value, the dog's typical range, and owner-friendly info.
/// Stateful only to fetch the dog's baseline once so each number carries a
/// plain-language status (Low/Normal/Elevated/High) relative to *this* dog.
class _VitalGrid extends StatefulWidget {
  const _VitalGrid({required this.repository, required this.dog, this.reading});

  final FurFeelRepository repository;
  final Dog dog;
  final TelemetryReading? reading;

  @override
  State<_VitalGrid> createState() => _VitalGridState();
}

class _VitalGridState extends State<_VitalGrid> {
  /// A week of readings behind each row's waveform.
  List<TelemetryReading> _recent = const [];

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  @override
  void didUpdateWidget(_VitalGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching dogs must not leave the previous dog's trend on screen.
    if (oldWidget.dog.id != widget.dog.id) {
      setState(() => _recent = const []);
      _loadTrend();
    }
  }

  void _loadTrend() {
    final dogId = widget.dog.id;
    final now = DateTime.now();
    // A week of readings, bucketed into the seven day-columns below.
    // ponytail: client-side daily averaging over up to ~1000 rows; a server
    // daily-vitals aggregate would be lighter if telemetry gets dense.
    widget.repository
        .fetchReadingsBetween(dogId, now.subtract(const Duration(days: 7)), now)
        .then((rows) {
      // A slow response for a dog the user already navigated away from must
      // not overwrite the current one.
      if (mounted && dogId == widget.dog.id) {
        setState(() => _recent = rows);
      }
    }).catchError((_) {});
  }

  /// Dense recent values for one vital, oldest first, for the waveform row.
  /// Downsampled so a week of readings reads as a smooth wave, not a smear.
  List<double> _waveValues(VitalKind kind) {
    double? pick(TelemetryReading r) => switch (kind) {
          VitalKind.heartRate => r.heartRateBpm?.toDouble(),
          VitalKind.breathing => r.respiratoryRateBpm?.toDouble(),
          VitalKind.activity => r.motionActivity,
        };

    final values = <double>[];
    for (final r in _recent) {
      final v = pick(r);
      if (v != null) values.add(v);
    }
    if (values.length < 2) return const [];
    const target = 28;
    if (values.length <= target) return values;
    final step = values.length / target;
    return [for (var i = 0; i < target; i++) values[(i * step).floor()]];
  }

  FurFeelRepository get repository => widget.repository;
  Dog get dog => widget.dog;
  TelemetryReading? get reading => widget.reading;

  @override
  Widget build(BuildContext context) {
    final activityState = reading == null
        ? ActivityState.noSignal
        : activityStateFrom(
            posture: reading!.posture,
            motionActivity: reading!.motionActivity,
          );

    (String, String) valueAndUnit(VitalKind kind) => switch (kind) {
          VitalKind.heartRate => (reading?.heartRateBpm?.toString() ?? '—', 'bpm'),
          VitalKind.breathing =>
            (reading?.respiratoryRateBpm?.toString() ?? '—', 'bpm'),
          VitalKind.activity => (activityState.label, ''),
        };

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _VitalBentoCard(
                color: VitalKind.heartRate.color(context),
                icon: VitalKind.heartRate.icon,
                label: VitalKind.heartRate.label,
                value: valueAndUnit(VitalKind.heartRate).$1,
                unit: valueAndUnit(VitalKind.heartRate).$2,
                series: _waveValues(VitalKind.heartRate),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VitalDetailPage(
                      repository: repository,
                      dog: dog,
                      kind: VitalKind.heartRate,
                      reading: reading,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: FurFeelTokens.space3),
            Expanded(
              child: _VitalBentoCard(
                color: VitalKind.activity.color(context),
                icon: VitalKind.activity.icon,
                label: VitalKind.activity.label,
                value: valueAndUnit(VitalKind.activity).$1,
                unit: valueAndUnit(VitalKind.activity).$2,
                series: _waveValues(VitalKind.activity),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VitalDetailPage(
                      repository: repository,
                      dog: dog,
                      kind: VitalKind.activity,
                      reading: reading,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: FurFeelTokens.space3),
        _VitalBentoCard(
          isWide: true,
          color: VitalKind.breathing.color(context),
          icon: VitalKind.breathing.icon,
          label: VitalKind.breathing.label,
          value: valueAndUnit(VitalKind.breathing).$1,
          unit: valueAndUnit(VitalKind.breathing).$2,
          series: _waveValues(VitalKind.breathing),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VitalDetailPage(
                repository: repository,
                dog: dog,
                kind: VitalKind.breathing,
                reading: reading,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VitalBentoCard extends StatelessWidget {
  const _VitalBentoCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.series,
    required this.onTap,
    this.isWide = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final List<double> series;
  final VoidCallback onTap;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    return PressScale(
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
          child: Container(
            height: isWide ? 120 : 150,
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
              boxShadow: FurFeelTokens.shadowCard, // Using the beautiful soft shadow
            ),
            child: isWide ? _buildWide(context) : _buildSquare(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSquare(BuildContext context) {
    final p = context.ff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.inkMuted,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text.rich(
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: p.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            children: [
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: p.inkMuted,
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Container(
          height: 36,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: series.isNotEmpty
              ? WaveSparkline(series: series, color: color)
              : Center(child: Text('—', style: TextStyle(color: p.inkMuted))),
        ),
      ],
    );
  }

  Widget _buildWide(BuildContext context) {
    final p = context.ff;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: p.inkMuted,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: Container(
            height: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: series.isNotEmpty
                ? WaveSparkline(series: series, color: color)
                : Center(child: Text('—', style: TextStyle(color: p.inkMuted))),
          ),
        ),
      ],
    );
  }
}

class _TodaySoFar extends StatelessWidget {
  const _TodaySoFar({required this.daily});

  final List<DailyStressSummary> daily;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayShare = _summaryForDay(daily, today)?.calmShare;
    final yesterdayShare = _summaryForDay(daily, yesterday)?.calmShare;
    if (todayShare == null) return const SizedBox.shrink();

    final delta = yesterdayShare == null ? null : todayShare - yesterdayShare;
    final (trendIcon, trendColor, trendWord) = switch (delta) {
      null => (null, context.ff.inkMuted, null),
      >= 0.05 => (Icons.trending_up, context.ff.statusCalmFg, 'calmer than yesterday'),
      <= -0.05 => (Icons.trending_down, context.ff.warm, 'less calm than yesterday'),
      _ => (Icons.trending_flat, context.ff.inkMuted, 'about the same as yesterday'),
    };

    return Container(
      padding: const EdgeInsets.all(FurFeelTokens.space5),
      decoration: BoxDecoration(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        boxShadow: FurFeelTokens.shadowCard,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: todayShare),
              duration: context.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    color: context.ff.surfaceAlt,
                  ),
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    color: context.ff.statusCalmFg,
                  ),
                  Center(
                    child: Text(
                      '${(value * 100).round()}%',
                      style: TextStyle(
                        fontSize: FurFeelTokens.typeH3Size,
                        fontWeight: FontWeight.w800,
                        color: context.ff.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: FurFeelTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Calm Goal',
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeBodyMobileSize,
                    fontWeight: FontWeight.w700,
                    color: context.ff.ink,
                  ),
                ),
                if (trendWord != null) ...[
                  const SizedBox(height: FurFeelTokens.space2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(trendIcon, size: 14, color: trendColor),
                      ),
                      const SizedBox(width: FurFeelTokens.space2),
                      Flexible(
                        child: Text(
                          trendWord,
                          style: textTheme.bodySmall?.copyWith(
                            color: trendColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayBanner extends StatelessWidget {
  const _BirthdayBanner({required this.dog});
  final Dog dog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final age = dog.ageYears;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FurFeelTokens.space5),
      decoration: BoxDecoration(
        color: context.ff.warmSoft,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
      ),
      child: Row(
        children: [
          const Text('🎂', style: TextStyle(fontSize: 32)),
          const SizedBox(width: FurFeelTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Happy birthday, ${dog.name}!',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  age == null
                      ? 'Extra treats are in order today.'
                      : '$age today — extra treats are in order.',
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

class _CareInsightsCard extends StatelessWidget {
  const _CareInsightsCard({required this.guidance});

  final CareGuidance guidance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = context.ff;

    return ClipRRect(
      borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(FurFeelTokens.space5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                p.warmSoft.withValues(alpha: 0.8),
                p.warmSoft.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: p.warm.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: p.warm.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tips_and_updates_outlined, size: 16, color: p.warm),
                  ),
                  const SizedBox(width: FurFeelTokens.space3),
                  SectionHeader(title: 'Care insights'),
                ],
              ),
              const SizedBox(height: FurFeelTokens.space3),
              Text(
                guidance.title,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                guidance.body,
                style: textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: FurFeelTokens.space4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'General guidance from your care team — not a diagnosis.',
                  style: textTheme.bodySmall?.copyWith(color: p.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
