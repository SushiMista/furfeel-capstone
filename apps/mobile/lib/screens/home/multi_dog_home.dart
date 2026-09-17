import 'package:flutter/material.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/dog_avatar.dart';
import 'package:furfeel_mobile/widgets/overview_stats_card.dart';
import 'package:furfeel_mobile/widgets/pet_selector.dart';
import 'package:furfeel_mobile/widgets/skeletons.dart';
import 'package:furfeel_mobile/widgets/stress_pill.dart';
import 'package:furfeel_mobile/screens/dogs/dog_detail_page.dart';

/// Multi-dog Home (QA item 9): one minimalist glance row per owned dog —
/// photo, name, breed, stress pill; numbers live on the dog's own page.
/// Tapping a card opens the dog's full detail. Single-dog owners never see
/// this; RootShell routes them straight to the rich detail.
class MultiDogHomeTab extends StatefulWidget {
  const MultiDogHomeTab({super.key, required this.repository, required this.dogs});

  final FurFeelRepository repository;
  final List<Dog> dogs;

  @override
  State<MultiDogHomeTab> createState() => _MultiDogHomeTabState();
}

class _MultiDogHomeTabState extends State<MultiDogHomeTab> {
  List<DogOverview>? _overviews;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MultiDogHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dogs.length != widget.dogs.length) _load();
  }

  Future<void> _load() async {
    try {
      final overviews =
          await Future.wait(widget.dogs.map(widget.repository.fetchDogOverview));
      if (!mounted) return;
      setState(() {
        _overviews = overviews;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _error = 'Couldn\'t load your pack right now — pull down to retry.');
    }
  }

  Future<void> _openDog(Dog dog) {
    return Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => DogDetailPage(
              repository: widget.repository,
              dog: dog,
              dogsCount: widget.dogs.length,
            ),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final overviews = _overviews;
    if (overviews == null && _error == null) return const HomeSkeleton();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // The Home tab has no app bar (the immersive hero owns the top), so the
        // pack greeting clears the status-bar inset itself.
        padding: EdgeInsets.fromLTRB(
          FurFeelTokens.space4,
          FurFeelTokens.space4 + MediaQuery.paddingOf(context).top,
          FurFeelTokens.space4,
          FurFeelTokens.space6 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _PackGreeting(dogCount: widget.dogs.length),
          const SizedBox(height: FurFeelTokens.space3),
          if (widget.dogs.length > 1) ...[
            // Board's "My Pets" row: quick jump to any dog
            PetSelector(
              dogs: widget.dogs,
              repository: widget.repository,
              onSelect: _openDog,
            ).entrance(context),
            const SizedBox(height: FurFeelTokens.space3),
          ],
          // At-a-glance overview strip (mirrors the dashboard's clinic KPI
          // row) — built from the same per-dog overviews already fetched
          // above; no extra query.
          if (overviews != null) ...[
            OverviewStatsCard(stats: _overviewStats(overviews)).entrance(context),
            const SizedBox(height: FurFeelTokens.space3),
          ],
          if (overviews == null)
            Padding(
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              child: Text(_error!, style: textTheme.bodyMedium),
            )
          else
            for (final (i, overview) in overviews.indexed)
              Padding(
                padding: EdgeInsets.only(top: i > 0 ? FurFeelTokens.space3 : 0),
                child: DogOverviewCard(
                  overview: overview,
                  repository: widget.repository,
                  onTap: () => _openDog(overview.dog),
                ).entrance(context, index: 1 + i),
              ),
        ],
      ),
    );
  }
}

/// Pack-wide stats (mirrors the dashboard's clinic KPI row), all derived
/// from the per-dog [DogOverview]s already fetched by [_MultiDogHomeTabState._load].
List<OverviewStat> _overviewStats(List<DogOverview> overviews) {
  final needsAttention = overviews
      .where((o) => o.classification != null && o.classification!.stressLevel != StressLevel.calm)
      .length;
  final devicesOffline = overviews.where((o) => o.device?.status == 'offline').length;
  final withWellness = overviews.where((o) => o.wellness != null).toList();
  final calmToday = withWellness.isEmpty
      ? null
      : withWellness.map((o) => o.wellness!.calmPercent).reduce((a, b) => a + b) /
          withWellness.length;
  // "Today" not "open": dog_wellness_score counts alerts raised today, not
  // current open/ack status (that needs a per-dog alerts query we don't have
  // here) — label it honestly rather than borrowing the dashboard's wording.
  final alertsToday = overviews.fold<int>(0, (sum, o) => sum + (o.wellness?.alertCount ?? 0));

  return [
    if (overviews.length > 1)
      OverviewStat(label: 'Dogs monitored', value: '${overviews.length}', icon: Icons.pets),
    if (calmToday != null)
      OverviewStat(
        label: 'Calm today',
        value: '${calmToday.round()}%',
        icon: Icons.favorite_outline,
      ),
    OverviewStat(
      label: 'Needs attention',
      value: '$needsAttention',
      icon: Icons.monitor_heart_outlined,
      attention: needsAttention > 0,
    ),
    OverviewStat(
      label: 'Alerts today',
      value: '$alertsToday',
      icon: Icons.notifications_outlined,
      attention: alertsToday > 0,
    ),
    OverviewStat(
      label: 'Devices offline',
      value: '$devicesOffline',
      icon: Icons.wifi_off,
      attention: devicesOffline > 0,
    ),
  ];
}

class _PackGreeting extends StatelessWidget {
  const _PackGreeting({required this.dogCount});
  
  final int dogCount;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null ? word : '$word, $name',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 2),
        Text(dogCount > 1 ? 'Here\'s how your pack is doing' : 'Here\'s how your dog is doing',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ).entrance(context);
  }
}

/// One glanceable dog card. Word + color everywhere, never color alone.
class DogOverviewCard extends StatefulWidget {
  const DogOverviewCard({
    super.key,
    required this.overview,
    required this.repository,
    required this.onTap,
  });

  final DogOverview overview;
  final FurFeelRepository repository;
  final VoidCallback onTap;

  @override
  State<DogOverviewCard> createState() => _DogOverviewCardState();
}

class _DogOverviewCardState extends State<DogOverviewCard> {
  Future<String>? _photoFuture;

  @override
  void initState() {
    super.initState();
    _initFuture();
  }

  @override
  void didUpdateWidget(DogOverviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overview.dog.photoPath != widget.overview.dog.photoPath) {
      _initFuture();
    }
  }

  void _initFuture() {
    final path = widget.overview.dog.photoPath;
    _photoFuture = path == null ? null : widget.repository.getSignedMediaUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dog = widget.overview.dog;
    final level = widget.overview.classification?.stressLevel;
    final tint = dogTint(context, dog);

    return PressScale(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
          child: FutureBuilder<String>(
            future: _photoFuture,
            builder: (context, snapshot) {
              final imageUrl = snapshot.data;

              return Container(
                height: 260,
                decoration: BoxDecoration(
                  color: imageUrl == null ? tint : null,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
                  image: imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: FurFeelTokens.shadowCard,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.transparent,
                        context.ff.brandInk.withValues(alpha: 0.5),
                        context.ff.brandInk.withValues(alpha: 0.9),
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.all(FurFeelTokens.space5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (level != null)
                            StressPill(level: level)
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'No data yet',
                                style: textTheme.labelSmall?.copyWith(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        dog.name,
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (dog.breed != null) dog.breed!,
                          if (dog.ageYears != null) '${dog.ageYears}y',
                        ].join(' · '),
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: FurFeelTokens.space4),
                      Row(
                        children: [
                          _MiniStat(
                            icon: Icons.favorite_border,
                            label: widget.overview.reading?.heartRateBpm != null
                                ? '${widget.overview.reading!.heartRateBpm} bpm'
                                : '--',
                            color: Colors.white,
                            bgColor: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(width: FurFeelTokens.space3),
                          _MiniStat(
                            icon: Icons.notifications_none,
                            label: '${widget.overview.wellness?.alertCount ?? 0} alerts',
                            color: Colors.white,
                            bgColor: Colors.white.withValues(alpha: 0.2),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
