import 'package:flutter/material.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/insights/biometrics.dart';
import 'package:furfeel_mobile/insights/owner_moments.dart';
import 'package:furfeel_mobile/models/activity_state.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/day_timeline.dart';
import 'package:furfeel_mobile/widgets/setup_checklist_card.dart';
import 'package:furfeel_mobile/widgets/curved_status_header.dart';
import 'package:furfeel_mobile/widgets/section_header.dart';
import 'package:furfeel_mobile/widgets/wave_sparkline.dart';
import 'package:furfeel_mobile/screens/dogs/device_pairing_page.dart';
import 'package:furfeel_mobile/screens/dogs/dog_form_page.dart';
import 'package:furfeel_mobile/screens/vitals/vital_detail_page.dart';
import 'package:furfeel_mobile/screens/settings/settings_page.dart';

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

    // Owner-delight pass: a new owner always sees the next step, never an
    // unexplained empty screen.
    final setup = setupProgress(
      hasDevice: widget.device != null,
      hasClinic: widget.dog.clinicId != null,
      hasReading: widget.reading != null,
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
                if (!setupComplete(setup)) ...[
                  SetupChecklistCard(
                    dogName: widget.dog.name,
                    progress: setup,
                    onPairHarness: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DevicePairingPage(
                            repository: widget.repository, dog: widget.dog),
                      ),
                    ),
                    onLinkClinic: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DogFormPage(
                            repository: widget.repository, dog: widget.dog),
                      ),
                    ),
                  ).entrance(context),
                  const SizedBox(height: FurFeelTokens.space4),
                ],
                // Health overview — one waveform row per vital, each its own
                // colour, opening a detail screen (docs/22 v7, ADR-023).
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
      trailing: HeaderCircleButton(
        icon: Icons.settings_outlined,
        tooltip: 'Settings',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
        ),
      ),
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
          VitalKind.temperature => r.bodyTemperatureC,
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
    final settings = SettingsScope.of(context);

    // Activity shows what the dog is doing, not a raw 0-1 index -- posture +
    // intensity mapped to a word (docs/04: a glance should answer without a
    // sensor feed). Squares with no reading show a dash.
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
          VitalKind.temperature => (
              settings.formatTemperature(reading?.bodyTemperatureC),
              settings.temperatureUnitLabel,
            ),
          VitalKind.activity => (activityState.label, ''),
        };

    // Health-overview rows (docs/22 v7): a coloured icon chip, the value, the
    // label, and a smooth waveform in the metric's own colour (ADR-023).
    return Column(
      children: [
        for (final (i, kind) in VitalKind.values.indexed) ...[
          if (i > 0) const SizedBox(height: FurFeelTokens.space3),
          _VitalWaveRow(
            color: kind.color(context),
            icon: kind.icon,
            label: kind.label,
            value: valueAndUnit(kind).$1,
            unit: valueAndUnit(kind).$2,
            series: _waveValues(kind),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VitalDetailPage(
                  repository: repository,
                  dog: dog,
                  kind: kind,
                  reading: reading,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One Home health-overview row: coloured icon chip · value + label · waveform.
class _VitalWaveRow extends StatelessWidget {
  const _VitalWaveRow({
    required this.color,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.series,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final List<double> series;
  final VoidCallback onTap;

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
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            // No hairline border — pure-white capsule with just a soft shadow,
            // matching docs/22 v8 (the border read as grey/dark).
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
              boxShadow: FurFeelTokens.shadowCard,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: FurFeelTokens.space3),
                SizedBox(
                  width: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: value,
                          style: TextStyle(
                            fontSize: FurFeelTokens.typeH1Size,
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          children: [
                            if (unit.isNotEmpty)
                              TextSpan(
                                text: ' $unit',
                                style: TextStyle(
                                  fontSize: FurFeelTokens.typeBodyMobileSize,
                                  fontWeight: FontWeight.w300,
                                  color: p.inkMuted,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: FurFeelTokens.typeBodyMobileSize,
                          fontWeight: FontWeight.w300,
                          color: p.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Graph sits right of the label, a fixed tinted panel (not
                // stretched full width, per docs/22 v8) with the chevron right.
                const Spacer(),
                Container(
                  width: 120,
                  height: 48,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
                  ),
                  child: WaveSparkline(series: series, color: color, height: 48),
                ),
                const SizedBox(width: FurFeelTokens.space2),
                Icon(Icons.chevron_right, size: 18, color: p.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Today so far" card — QA: the calm share is a visual, not just a line of
/// text. A ring fills with the calm share; the delta vs yesterday sits beside
/// it with a trend icon (word + icon, never color alone).
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
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      decoration: BoxDecoration(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        border: Border.all(color: context.ff.hairline),
      ),
      child: Row(
        children: [
          // Calm-share ring: animates to the current share, instant under
          // reduced motion.
          SizedBox(
            width: 64,
            height: 64,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: todayShare),
              duration: context.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: context.ff.statusCalmFg,
                    backgroundColor: context.ff.surfaceAlt,
                  ),
                  Center(
                    child: Text(
                      '${(value * 100).round()}%',
                      style: TextStyle(
                        fontSize: FurFeelTokens.typeH3Size,
                        fontWeight: FontWeight.w700,
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
                  'Calm today so far',
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeBodyMobileSize,
                    fontWeight: FontWeight.w600,
                    color: context.ff.ink,
                  ),
                ),
                if (trendWord != null) ...[
                  const SizedBox(height: FurFeelTokens.space1),
                  Row(
                    children: [
                      Icon(trendIcon, size: 16, color: trendColor),
                      const SizedBox(width: FurFeelTokens.space1),
                      Flexible(
                        child: Text(
                          trendWord,
                          style: textTheme.bodySmall?.copyWith(color: trendColor),
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

/// Birthday moment (owner-delight pass): a warm one-liner on the dog's day.
/// Purely celebratory — no data claims.
class _BirthdayBanner extends StatelessWidget {
  const _BirthdayBanner({required this.dog});

  final Dog dog;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final age = dog.ageYears;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      decoration: BoxDecoration(
        color: context.ff.warmSoft,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
      ),
      child: Row(
        children: [
          const Text('🎂', style: TextStyle(fontSize: 28)),
          const SizedBox(width: FurFeelTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Happy birthday, ${dog.name}!',
                  style:
                      textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

/// Care Insights (docs/04 module 4): vet-authored plain-language guidance for
/// the current stress level. Informational only — never diagnosis.
class _CareInsightsCard extends StatelessWidget {
  const _CareInsightsCard({required this.guidance});

  final CareGuidance guidance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FurFeelTokens.space5),
      decoration: BoxDecoration(
        // Owner-app warmth layer (docs/19): warm tinted card, warm accent.
        color: context.ff.warmSoft,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 18, color: context.ff.warm),
              const SizedBox(width: FurFeelTokens.space2),
              SectionHeader(title: 'Care insights'),
            ],
          ),
          const SizedBox(height: FurFeelTokens.space2),
          Text(guidance.title, style: textTheme.titleMedium),
          const SizedBox(height: FurFeelTokens.space2),
          Text(guidance.body, style: textTheme.bodyMedium),
          const SizedBox(height: FurFeelTokens.space3),
          Text(
            'General guidance from your care team — not a diagnosis.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
