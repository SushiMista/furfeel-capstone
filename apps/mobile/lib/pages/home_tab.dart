import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/friendly_time.dart';
import '../util/motion.dart';
import '../widgets/dog_avatar.dart';
import '../widgets/stress_pill.dart';
import '../widgets/vet_note_card.dart';
import 'observation_page.dart';
import 'vet_review_page.dart';
import 'vital_detail_page.dart';

/// Owner home (docs/04 module 1): "how is my dog right now, and what should I
/// do?" — status hero, today-so-far calm stat, care insights for the current
/// stress level, and quick links. Raw readings live in the detailed log; a
/// glance here should answer the question without scrolling a sensor feed.
class HomeTab extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final level = classification?.stressLevel;
    final careGuidance =
        level == null ? null : selectCareGuidance(guidance, level, dog.clinicId);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          // ADDED: personalized greeting by name + time of day (docs/04).
          const _Greeting(),
          const SizedBox(height: FurFeelTokens.space3),
          _StatusHero(
            repository: repository,
            dog: dog,
            reading: reading,
            classification: classification,
            device: device,
          ).entrance(context, index: 1),
          const SizedBox(height: FurFeelTokens.space3),
          // QA: vitals as four tappable squares; each opens a detail screen
          // with the dog's typical range + owner-friendly info.
          _VitalGrid(repository: repository, dog: dog, reading: reading)
              .entrance(context, index: 2),
          const SizedBox(height: FurFeelTokens.space3),
          _TodaySoFar(daily: daily).entrance(context, index: 3),
          if (careGuidance != null) ...[
            const SizedBox(height: FurFeelTokens.space5),
            _CareInsightsCard(guidance: careGuidance).entrance(context, index: 4),
          ],
          // QA: clinician comments surface right here — no navigation needed.
          if (vetNotes.isNotEmpty) ...[
            const SizedBox(height: FurFeelTokens.space5),
            Text('FROM YOUR CARE TEAM',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: FurFeelTokens.space2),
            for (final (i, note) in vetNotes.take(2).indexed)
              Padding(
                padding: EdgeInsets.only(top: i > 0 ? FurFeelTokens.space3 : 0),
                child: VetNoteCard(repository: repository, note: note)
                    .entrance(context, index: 5 + i),
              ),
          ],
          const SizedBox(height: FurFeelTokens.space5),
          Row(
            children: [
              Expanded(
                child: _QuickLink(
                  icon: Icons.medical_information_outlined,
                  label: 'Vet review',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VetReviewPage(repository: repository, dog: dog),
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
                      builder: (_) => ObservationPage(repository: repository, dog: dog),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
class _VitalGrid extends StatelessWidget {
  const _VitalGrid({required this.repository, required this.dog, this.reading});

  final FurFeelRepository repository;
  final Dog dog;
  final TelemetryReading? reading;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);

    (String, String) valueAndUnit(VitalKind kind) => switch (kind) {
          VitalKind.heartRate => (reading?.heartRateBpm?.toString() ?? '—', 'bpm'),
          VitalKind.breathing =>
            (reading?.respiratoryRateBpm?.toString() ?? '—', 'bpm'),
          VitalKind.temperature => (
              settings.formatTemperature(reading?.bodyTemperatureC),
              settings.temperatureUnitLabel,
            ),
          VitalKind.activity =>
            (reading?.motionActivity?.toStringAsFixed(1) ?? '—', ''),
        };

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: FurFeelTokens.space3,
      crossAxisSpacing: FurFeelTokens.space3,
      childAspectRatio: 1.55,
      children: [
        for (final kind in VitalKind.values)
          _VitalSquare(
            kind: kind,
            value: valueAndUnit(kind).$1,
            unit: valueAndUnit(kind).$2,
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
  });

  final VitalKind kind;
  final String value;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PressScale(
      child: Material(
        color: FurFeelTokens.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            decoration: BoxDecoration(
              border: Border.all(color: FurFeelTokens.hairline),
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(kind.icon, size: 18, color: FurFeelTokens.brand),
                    const SizedBox(width: FurFeelTokens.space2),
                    Expanded(
                      child: Text(
                        kind.label,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: FurFeelTokens.inkMuted),
                  ],
                ),
                // Cross-fades on updates (docs/19 §5a), instant under
                // reduced motion.
                AnimatedSwitcher(
                  duration: context.reduceMotion
                      ? Duration.zero
                      : FurFeelTokens.motionSlow,
                  child: Text.rich(
                    key: ValueKey(value),
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: FurFeelTokens.typeVitalNumberSize,
                        fontWeight: FurFeelTokens.typeVitalNumberWeight,
                        color: FurFeelTokens.ink,
                        height: 1.1,
                      ),
                      children: [
                        if (unit.isNotEmpty)
                          TextSpan(
                            text: ' $unit',
                            style: TextStyle(
                              fontSize: FurFeelTokens.typeCaptionSize,
                              fontWeight: FontWeight.w400,
                              color: FurFeelTokens.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
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

    DailyStressSummary? forDay(DateTime day) {
      for (final d in daily) {
        if (d.day.year == day.year && d.day.month == day.month && d.day.day == day.day) {
          return d;
        }
      }
      return null;
    }

    final todayShare = forDay(today)?.calmShare;
    final yesterdayShare = forDay(yesterday)?.calmShare;
    if (todayShare == null) return const SizedBox.shrink();

    final delta = yesterdayShare == null ? null : todayShare - yesterdayShare;
    final (trendIcon, trendColor, trendWord) = switch (delta) {
      null => (null, FurFeelTokens.inkMuted, null),
      >= 0.05 => (Icons.trending_up, FurFeelTokens.statusCalmFg, 'calmer than yesterday'),
      <= -0.05 => (Icons.trending_down, FurFeelTokens.warm, 'less calm than yesterday'),
      _ => (Icons.trending_flat, FurFeelTokens.inkMuted, 'about the same as yesterday'),
    };

    return Container(
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      decoration: BoxDecoration(
        color: FurFeelTokens.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        border: Border.all(color: FurFeelTokens.hairline),
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
                    color: FurFeelTokens.statusCalmFg,
                    backgroundColor: FurFeelTokens.surfaceAlt,
                  ),
                  Center(
                    child: Text(
                      '${(value * 100).round()}%',
                      style: TextStyle(
                        fontSize: FurFeelTokens.typeH3Size,
                        fontWeight: FontWeight.w700,
                        color: FurFeelTokens.ink,
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
                    color: FurFeelTokens.ink,
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
                      level != null ? stressLevelSoftBg(level) : FurFeelTokens.brandSoft,
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

/// Small connectivity chip (docs/04 module 6: show connectivity states).
class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final offline = device.status == 'offline';
    final color = device.isOnline
        ? FurFeelTokens.statusCalmFg
        : offline
            ? FurFeelTokens.statusHighOwner
            : FurFeelTokens.inkMuted;
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
        color: FurFeelTokens.warmSoft,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 18, color: FurFeelTokens.warm),
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
      color: FurFeelTokens.surface,
      borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(FurFeelTokens.space4),
          decoration: BoxDecoration(
            border: Border.all(color: FurFeelTokens.hairline),
            borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          ),
          child: Column(
            children: [
              Icon(icon, color: FurFeelTokens.brand),
              const SizedBox(height: FurFeelTokens.space2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: FurFeelTokens.typeLabelSize,
                  fontWeight: FontWeight.w600,
                  color: FurFeelTokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
