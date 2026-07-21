import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../insights/biometrics.dart';
import '../insights/owner_moments.dart';
import '../models/activity_state.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/battery.dart';
import '../util/friendly_time.dart';
import '../util/motion.dart';
import '../widgets/activity_indicator.dart';
import '../widgets/day_timeline.dart';
import '../widgets/dog_avatar.dart';
import '../widgets/overview_stats_card.dart';
import '../widgets/setup_checklist_card.dart';
import '../widgets/stress_pill.dart';
import '../widgets/vet_note_card.dart';
import 'device_pairing_page.dart';
import 'dog_form_page.dart';
import 'observation_page.dart';
import 'vet_review_page.dart';
import 'vital_detail_page.dart';

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
    required this.vetNotes,
    required this.onRefresh,
    required this.dogsCount,
    required this.alerts,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final TelemetryReading? reading;
  final StressClassification? classification;
  final List<DailyStressSummary> daily;
  final Device? device;
  final List<CareGuidance> guidance;
  final List<VetNoteFeedItem> vetNotes;
  final Future<void> Function() onRefresh;

  /// Total dogs on this account and this dog's own alerts — both already
  /// loaded by RootShell, just plumbed through for the overview card below.
  final int dogsCount;
  final List<Alert> alerts;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _selectedTabIndex = 0;

  /// Same five stats as the dashboard's clinic KPI row, scoped to this
  /// account (docs/04 Home): only ever 1 dog here, so it mostly restates
  /// today's status hero as a scannable strip.
  List<OverviewStat> _overviewStats() {
    final today = _summaryForDay(widget.daily, DateTime.now());
    final calmToday = today?.calmShare;
    final needsAttention =
        widget.classification != null && widget.classification!.stressLevel != StressLevel.calm
            ? 1
            : 0;
    final openAlerts = widget.alerts.where((a) => a.isOpen).length;
    final devicesOffline = widget.device?.status == 'offline' ? 1 : 0;

    return [
      OverviewStat(
        label: 'Dogs monitored',
        value: '${widget.dogsCount}',
        icon: Icons.pets,
      ),
      if (calmToday != null)
        OverviewStat(
          label: 'Calm today',
          value: '${(calmToday * 100).round()}%',
          icon: Icons.favorite_outline,
        ),
      OverviewStat(
        label: 'Needs attention',
        value: '$needsAttention',
        icon: Icons.monitor_heart_outlined,
        attention: needsAttention > 0,
      ),
      OverviewStat(
        label: 'Open alerts',
        value: '$openAlerts',
        icon: Icons.notifications_outlined,
        attention: openAlerts > 0,
      ),
      OverviewStat(
        label: 'Devices offline',
        value: '$devicesOffline',
        icon: Icons.wifi_off,
        attention: devicesOffline > 0,
      ),
    ];
  }

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

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          // ADDED: personalized greeting by name + time of day (docs/04).
          const _Greeting(),
          const SizedBox(height: FurFeelTokens.space3),
          // At-a-glance overview strip (mirrors the dashboard's clinic KPI
          // row) — built entirely from data RootShell already loaded.
          OverviewStatsCard(stats: _overviewStats()).entrance(context),
          const SizedBox(height: FurFeelTokens.space3),
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
                  builder: (_) =>
                      DevicePairingPage(repository: widget.repository, dog: widget.dog),
                ),
              ),
              onLinkClinic: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DogFormPage(repository: widget.repository, dog: widget.dog),
                ),
              ),
            ).entrance(context),
            const SizedBox(height: FurFeelTokens.space3),
          ],
          _StatusHero(
            repository: widget.repository,
            dog: widget.dog,
            reading: widget.reading,
            classification: widget.classification,
            device: widget.device,
          ).entrance(context, index: 1),
          const SizedBox(height: FurFeelTokens.space3),

          // Custom horizontal tab selector
          _HomeTabBar(
            selectedIndex: _selectedTabIndex,
            onTabSelected: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
          ).entrance(context, index: 2),
          const SizedBox(height: FurFeelTokens.space3),

          // Tab content based on index
          if (_selectedTabIndex == 0) ...[
            // Tab 0: Vitals
            if (widget.device != null) ...[
              _BatteryHealthCard(
                device: widget.device!,
                dogName: widget.dog.name,
                onManage: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DevicePairingPage(repository: widget.repository, dog: widget.dog),
                  ),
                ),
              ).entrance(context, index: 3),
              const SizedBox(height: FurFeelTokens.space3),
            ],
            // QA: vitals as four tappable squares; each opens a detail screen
            // with the dog's typical range + owner-friendly info.
            _VitalGrid(
              repository: widget.repository,
              dog: widget.dog,
              reading: widget.reading,
            ).entrance(context, index: 4),
          ] else if (_selectedTabIndex == 1) ...[
            // Tab 1: Activity
            _TodaySoFar(daily: widget.daily).entrance(context, index: 3),
            const SizedBox(height: FurFeelTokens.space3),
            // Owner-delight pass: the day as a banded strip (docs/19 §6).
            DayTimeline(
              repository: widget.repository,
              dog: widget.dog,
            ).entrance(context, index: 4),
          ] else ...[
            // Tab 2: Care Team
            if (careGuidance != null) ...[
              _CareInsightsCard(guidance: careGuidance).entrance(context, index: 3),
              const SizedBox(height: FurFeelTokens.space4),
            ],
            // QA: clinician comments surface right here — no navigation needed.
            if (widget.vetNotes.isNotEmpty) ...[
              Text('FROM YOUR CARE TEAM',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: FurFeelTokens.space2),
              for (final (i, note) in widget.vetNotes.take(2).indexed)
                Padding(
                  padding: EdgeInsets.only(top: i > 0 ? FurFeelTokens.space3 : 0),
                  child: VetNoteCard(repository: widget.repository, note: note)
                      .entrance(context, index: 4 + i),
                ),
              const SizedBox(height: FurFeelTokens.space4),
            ],
            Row(
              children: [
                Expanded(
                  child: _QuickLink(
                    icon: Icons.medical_information_outlined,
                    label: 'Vet review',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VetReviewPage(repository: widget.repository, dog: widget.dog),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: FurFeelTokens.space3),
                Expanded(
                  child: _QuickLink(
                    icon: Icons.photo_camera_outlined,
                    label: 'Share an observation',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ObservationPage(repository: widget.repository, dog: widget.dog),
                      ),
                    ),
                  ),
                ),
              ],
            ).entrance(context, index: 6),
          ],
        ],
      ),
    );
  }
}

/// ADDED: warm greeting header — first name + time of day, per docs/04
/// ("Good morning, Joshua" with the dog front and center below).
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final name = controller.profile?.firstName;
    final hour = DateTime.now().hour;
    final word = switch (hour) {
      >= 5 && < 12 => 'Good morning',
      >= 12 && < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    return Text(
      name == null ? word : '$word, $name',
      style: Theme.of(context).textTheme.headlineMedium,
    ).entrance(context);
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
  DogBaseline? _baseline;

  @override
  void initState() {
    super.initState();
    widget.repository.fetchBaseline(widget.dog.id).then((b) {
      if (mounted) setState(() => _baseline = b);
    }).catchError((_) {});
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

    // QA item 10: a status word next to the number, from the dog's own
    // baseline when the clinic set one (else the provisional global range).
    VitalStatus? status(VitalKind kind) => switch (kind) {
          VitalKind.heartRate => heartRateStatus(reading?.heartRateBpm, _baseline),
          VitalKind.breathing =>
            respiratoryStatus(reading?.respiratoryRateBpm, _baseline),
          VitalKind.temperature => temperatureStatus(reading?.bodyTemperatureC),
          VitalKind.activity => null, // activity already reads as a word
        };

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: FurFeelTokens.space3,
      crossAxisSpacing: FurFeelTokens.space3,
      // Slightly taller squares: value + status word need the room.
      childAspectRatio: 1.35,
      children: [
        for (final kind in VitalKind.values)
          _VitalSquare(
            kind: kind,
            value: valueAndUnit(kind).$1,
            unit: valueAndUnit(kind).$2,
            status: status(kind),
            activityState: kind == VitalKind.activity ? activityState : null,
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
    );
  }
}

class _VitalSquare extends StatelessWidget {
  const _VitalSquare({
    required this.kind,
    required this.value,
    required this.unit,
    required this.onTap,
    this.status,
    this.activityState,
  });

  final VitalKind kind;
  final String value;
  final String unit;
  final VoidCallback onTap;

  /// Plain-language status (Low/Normal/Elevated/High) for this dog; null when
  /// there's no reading or the vital doesn't use one (activity).
  final VitalStatus? status;

  /// Set only on the Activity square: swaps the numeric value for an
  /// animated state indicator + state word.
  final ActivityState? activityState;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PressScale(
      child: Material(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            decoration: BoxDecoration(
              border: Border.all(color: context.ff.hairline),
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(kind.icon, size: 18, color: context.ff.brand),
                    const SizedBox(width: FurFeelTokens.space2),
                    Expanded(
                      child: Text(
                        kind.label,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: context.ff.inkMuted),
                  ],
                ),
                // Cross-fades on updates (docs/19 §5a), instant under
                // reduced motion.
                AnimatedSwitcher(
                  duration: context.reduceMotion
                      ? Duration.zero
                      : FurFeelTokens.motionSlow,
                  child: activityState != null
                      ? Row(
                          key: ValueKey(value),
                          children: [
                            ActivityIndicator(state: activityState!),
                            const SizedBox(width: FurFeelTokens.space2),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: FurFeelTokens.typeH2Size,
                                    fontWeight: FurFeelTokens.typeVitalNumberWeight,
                                    color: activityState == ActivityState.noSignal
                                        ? context.ff.inkMuted
                                        : context.ff.ink,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text.rich(
                          key: ValueKey(value),
                          TextSpan(
                            text: value,
                            style: TextStyle(
                              fontSize: FurFeelTokens.typeVitalNumberSize,
                              fontWeight: FurFeelTokens.typeVitalNumberWeight,
                              color: context.ff.ink,
                              height: 1.1,
                            ),
                            children: [
                              if (unit.isNotEmpty)
                                TextSpan(
                                  text: ' $unit',
                                  style: TextStyle(
                                    fontSize: FurFeelTokens.typeCaptionSize,
                                    fontWeight: FontWeight.w400,
                                    color: context.ff.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                if (status != null)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: vitalStatusColor(context, status!),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: FurFeelTokens.space1),
                      Text(
                        status!.label,
                        style: TextStyle(
                          fontSize: FurFeelTokens.typeCaptionSize,
                          fontWeight: FontWeight.w600,
                          color: vitalStatusColor(context, status!),
                        ),
                      ),
                    ],
                  ),
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

/// Dog status hero (docs/19 signature component): the dog + a large
/// cross-fading stress pill, encouraging phrase, big vitals, connectivity.
class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.repository,
    required this.dog,
    this.reading,
    this.classification,
    this.device,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final TelemetryReading? reading;
  final StressClassification? classification;
  final Device? device;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final level = classification?.stressLevel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DogAvatar(
                  dog: dog,
                  repository: repository,
                  backgroundColor:
                      level != null ? stressLevelSoftBg(context, level) : context.ff.brandSoft,
                ),
                const SizedBox(width: FurFeelTokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dog.name, style: textTheme.headlineMedium),
                      if (dog.breed != null) Text(dog.breed!, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                if (device != null) _DeviceChip(device: device!),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space4),
            if (level != null) ...[
              StressPill(level: level, large: true),
              const SizedBox(height: FurFeelTokens.space2),
              Text(level.phrase(dog.name), style: textTheme.bodyMedium),
            ] else
              Text(
                'No stress reading yet — we\'ll let you know how ${dog.name} '
                'is feeling as soon as the harness checks in.',
                style: textTheme.bodySmall,
              ),
            // QA: vitals moved out of the hero into their own 2x2 grid below —
            // this card stays a calm, uncluttered status statement.
            // Owner-delight pass: the environment around the dog, since heat/
            // cold often IS the story the classifier tells.
            if (reading?.ambientTemperatureC != null ||
                reading?.humidityPercent != null) ...[
              const SizedBox(height: FurFeelTokens.space3),
              Row(
                children: [
                  Icon(Icons.thermostat_outlined,
                      size: 16, color: context.ff.inkMuted),
                  const SizedBox(width: FurFeelTokens.space1),
                  Expanded(
                    child: Text(
                      [
                        if (reading!.ambientTemperatureC != null)
                          'Around ${dog.name}: '
                              '${SettingsScope.of(context).formatTemperature(reading!.ambientTemperatureC)}'
                              '${SettingsScope.of(context).temperatureUnitLabel}',
                        if (reading!.humidityPercent != null)
                          '${reading!.humidityPercent!.round()}% humidity',
                      ].join(' · '),
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: FurFeelTokens.space3),
            Text(
              reading != null
                  ? 'Last updated ${friendlyTimestamp(reading!.capturedAt)}'
                  : 'Waiting for the first reading…',
              style: textTheme.bodySmall,
            ),
          ],
        ),
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

/// Small connectivity chip (docs/04 module 6: show connectivity states) plus
/// harness battery (QA item 14) with a low-battery state.
class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final offline = device.status == 'offline';
    final color = device.isOnline
        ? context.ff.statusCalmFg
        : offline
            ? context.ff.statusHighOwner
            : context.ff.inkMuted;
    final battery = device.batteryPercent;
    final batteryColor =
        device.isBatteryLow ? context.ff.statusHighOwner : context.ff.inkMuted;
    final batteryIcon = battery == null ? null : batteryIconFor(battery);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(device.isOnline ? Icons.sensors : Icons.sensors_off, size: 16, color: color),
        const SizedBox(width: FurFeelTokens.space1),
        Text(
          device.status,
          style: TextStyle(
            fontSize: FurFeelTokens.typeCaptionSize,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (battery != null) ...[
          const SizedBox(width: FurFeelTokens.space2),
          Icon(batteryIcon, size: 14, color: batteryColor),
          Text(
            '$battery%',
            style: TextStyle(
              fontSize: FurFeelTokens.typeCaptionSize,
              fontWeight: FontWeight.w600,
              color: batteryColor,
            ),
          ),
        ],
      ],
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
              Text('CARE INSIGHTS', style: textTheme.labelSmall),
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

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ff.surface,
      borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(FurFeelTokens.space4),
          decoration: BoxDecoration(
            border: Border.all(color: context.ff.hairline),
            borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          ),
          child: Column(
            children: [
              Icon(icon, color: context.ff.brand),
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: FurFeelTokens.typeLabelSize,
                  fontWeight: FontWeight.w600,
                  color: context.ff.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A premium, tactile card displaying battery health, connectivity status,
/// and friendly contextual alerts for the paired dog harness (QA item 14).
class _BatteryHealthCard extends StatelessWidget {
  const _BatteryHealthCard({
    required this.device,
    required this.dogName,
    required this.onManage,
  });

  final Device device;
  final String dogName;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final battery = device.batteryPercent ?? 100;
    final isLow = device.isBatteryLow;
    final batteryColor = batteryColorFor(context, battery);
    final batteryIcon = batteryIconFor(battery);

    // Status description text based on battery health
    final String statusText;
    final String descriptionText;
    if (isLow) {
      statusText = 'Critical';
      descriptionText =
          'The harness battery is getting low ($battery%). Charge it soon so $dogName\'s monitoring doesn\'t pause.';
    } else if (battery <= 30) {
      statusText = 'Low';
      descriptionText =
          'The battery is low ($battery%). We recommend charging the harness soon.';
    } else {
      statusText = 'Healthy';
      descriptionText =
          'The battery is healthy ($battery%). $dogName\'s harness is actively monitoring.';
    }

    return Card(
      child: InkWell(
        onTap: onManage,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(FurFeelTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.battery_charging_full_rounded,
                      size: 18, color: context.ff.brand),
                  const SizedBox(width: FurFeelTokens.space2),
                  Expanded(
                    child: Text(
                      'HARNESS DEVICE & BATTERY',
                      style: textTheme.labelSmall,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: context.ff.inkMuted),
                ],
              ),
              const SizedBox(height: FurFeelTokens.space3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular Battery Gauge Visual representation
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: battery / 100.0,
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          color: batteryColor,
                          backgroundColor: context.ff.surfaceAlt,
                        ),
                      ),
                      Icon(batteryIcon, size: 22, color: batteryColor),
                    ],
                  ),
                  const SizedBox(width: FurFeelTokens.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$battery%',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: FurFeelTokens.space2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: FurFeelTokens.space2,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isLow
                                    ? context.ff.statusHighBg
                                    : battery <= 30
                                        ? context.ff.statusMildBg
                                        : context.ff.statusCalmBg,
                                borderRadius:
                                    BorderRadius.circular(FurFeelTokens.radiusPill),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isLow
                                      ? context.ff.statusHighOwner
                                      : battery <= 30
                                          ? context.ff.statusMildFg
                                          : context.ff.statusCalmFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.status == 'offline' ? 'Offline' : 'Connected',
                          style: TextStyle(
                            fontSize: FurFeelTokens.typeCaptionSize,
                            fontWeight: FontWeight.w600,
                            color: device.status == 'offline'
                                ? context.ff.statusHighOwner
                                : context.ff.statusCalmFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FurFeelTokens.space3),
              Text(
                descriptionText,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: context.ff.ink,
                ),
              ),
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                device.lastSeenAt != null
                    ? 'Last synced ${friendlyTimestamp(device.lastSeenAt!)}'
                    : 'No sync yet — put the harness on and give it a minute.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A premium custom horizontal segmented tab/pill selector for switching between
/// Vitals, Activity, and Care Team tabs (docs/19 §7).
class _HomeTabBar extends StatelessWidget {
  const _HomeTabBar({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.ff.surfaceAlt,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
      ),
      child: Row(
        children: [
          _buildTab(context, index: 0, label: 'Vitals', icon: Icons.analytics_outlined),
          _buildTab(context, index: 1, label: 'Activity', icon: Icons.trending_up_rounded),
          _buildTab(context, index: 2, label: 'Care Team', icon: Icons.healing_outlined),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context,
      {required int index, required String label, required IconData icon}) {
    final isSelected = selectedIndex == index;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: FurFeelTokens.space2),
          decoration: BoxDecoration(
            color: isSelected ? context.ff.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
            boxShadow: isSelected ? FurFeelTokens.shadowCard : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? context.ff.brand : context.ff.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: isSelected ? context.ff.brand : context.ff.inkMuted,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
