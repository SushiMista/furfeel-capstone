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
  String _sort = 'name';
  String? _error;
  final List<void Function()> _subscriptions = [];

  void _clearSubscriptions() {
    for (final unsub in _subscriptions) {
      unsub();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    _clearSubscriptions();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MultiDogHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dogs.length != widget.dogs.length) {
      _load();
    }
  }

  void _setupSubscriptions() {
    _clearSubscriptions();
    for (final dog in widget.dogs) {
      final unsub = widget.repository.subscribeToDog(
        dog.id,
        onReading: (reading) {
          if (!mounted || _overviews == null) return;
          setState(() {
            final idx = _overviews!.indexWhere((o) => o.dog.id == dog.id);
            if (idx != -1) {
              final old = _overviews![idx];
              _overviews![idx] = DogOverview(
                dog: old.dog,
                reading: reading,
                classification: old.classification,
                device: old.device,
                wellness: old.wellness,
                openAlertsCount: old.openAlertsCount,
              );
            }
          });
        },
        onClassification: (classification) {
          if (!mounted || _overviews == null) return;
          setState(() {
            final idx = _overviews!.indexWhere((o) => o.dog.id == dog.id);
            if (idx != -1) {
              final old = _overviews![idx];
              _overviews![idx] = DogOverview(
                dog: old.dog,
                reading: old.reading,
                classification: classification,
                device: old.device,
                wellness: old.wellness,
                openAlertsCount: old.openAlertsCount,
              );
            }
          });
        },
      );
      _subscriptions.add(unsub);
    }
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
      _setupSubscriptions();
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
            OverviewStatsCard(
              stats: _overviewStats(overviews),
              sortValue: _sort,
              onSortChanged: (v) => setState(() => _sort = v),
            ).entrance(context),
            const SizedBox(height: FurFeelTokens.space3),
          ],
          if (overviews == null)
            Padding(
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              child: Text(_error!, style: textTheme.bodyMedium),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: FurFeelTokens.space3),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Rebuild a custom animated grid
                  const crossAxisCount = 2;
                  const crossAxisSpacing = FurFeelTokens.space3;
                  const mainAxisSpacing = FurFeelTokens.space3;
                  const childAspectRatio = 0.75;

                  final width = constraints.maxWidth;
                  final itemWidth = (width - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
                  final itemHeight = itemWidth / childAspectRatio;

                  final sorted = List<DogOverview>.of(overviews);
                  sorted.sort((a, b) {
                    if (_sort == 'stress') {
                      final levelA = a.classification?.stressLevel.index ?? 0;
                      final levelB = b.classification?.stressLevel.index ?? 0;
                      if (levelA != levelB) return levelB.compareTo(levelA);
                    } else if (_sort == 'alerts') {
                      if (a.openAlertsCount != b.openAlertsCount) {
                        return b.openAlertsCount.compareTo(a.openAlertsCount);
                      }
                    }
                    return a.dog.name.compareTo(b.dog.name);
                  });

                  final rowCount = (sorted.length / crossAxisCount).ceil();
                  final totalHeight = rowCount * itemHeight + (rowCount > 0 ? rowCount - 1 : 0) * mainAxisSpacing;

                  return SizedBox(
                    height: totalHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < sorted.length; i++) ...[
                          (() {
                            final item = sorted[i];
                            final col = i % crossAxisCount;
                            final row = i ~/ crossAxisCount;
                            final left = col * (itemWidth + crossAxisSpacing);
                            final top = row * (itemHeight + mainAxisSpacing);

                            return AnimatedPositioned(
                              key: ValueKey(item.dog.id),
                              duration: FurFeelTokens.motionFast,
                              curve: Curves.easeInOutCubic,
                              left: left,
                              top: top,
                              width: itemWidth,
                              height: itemHeight,
                              child: DogOverviewCard(
                                overview: item,
                                repository: widget.repository,
                                onTap: () => _openDog(item.dog),
                              ),
                            );
                          })(),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Pack-wide stats (mirrors the dashboard's clinic KPI row), all derived
/// from the per-dog [DogOverview]s already fetched by [_MultiDogHomeTabState._load].
List<OverviewStat> _overviewStats(List<DogOverview> overviews) {
  final openAlerts = overviews.fold<int>(0, (sum, o) => sum + o.openAlertsCount);
  final needsAttention = overviews.where((o) => o.openAlertsCount > 0).length;
  final devicesOffline = overviews.where((o) => o.device?.status == 'offline').length;
  final withWellness = overviews.where((o) => o.wellness != null).toList();
  final calmToday = withWellness.isEmpty
      ? null
      : withWellness.map((o) => o.wellness!.calmPercent).reduce((a, b) => a + b) /
          withWellness.length;

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
      label: 'Open alerts',
      value: '$openAlerts',
      icon: Icons.notifications_outlined,
      attention: openAlerts > 0,
    ),
    if (devicesOffline > 0)
      OverviewStat(
        label: 'Sensors offline',
        value: '$devicesOffline',
        icon: Icons.wifi_off,
        attention: true,
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

    final p = context.ff;
    final baseColor = switch (level) {
      StressLevel.calm => p.statusCalmFg,
      StressLevel.mild => p.statusMildFg,
      StressLevel.moderate => p.statusModerateFg,
      StressLevel.high => p.statusHighFg,
      null => p.brandInk,
    };
    final darkColor = Color.lerp(baseColor, Colors.black, 0.4) ?? baseColor;

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
                        darkColor.withValues(alpha: 0.6),
                        darkColor.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.3, 0.6, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.all(FurFeelTokens.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (level != null)
                            Expanded(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: StressPill(level: level, onDark: true),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'No data',
                                style: textTheme.labelSmall?.copyWith(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        dog.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: FurFeelTokens.space3),
                      Wrap(
                        spacing: FurFeelTokens.space2,
                        runSpacing: FurFeelTokens.space2,
                        children: [
                          _MiniStat(
                            icon: Icons.favorite_border,
                            label: widget.overview.reading?.heartRateBpm != null
                                ? '${widget.overview.reading!.heartRateBpm} bpm'
                                : '--',
                            color: Colors.white,
                            bgColor: Colors.white.withValues(alpha: 0.2),
                          ),
                          _MiniStat(
                            icon: Icons.notifications_none,
                            label: '${widget.overview.openAlertsCount}',
                            color: Colors.white,
                            bgColor: Colors.white.withValues(alpha: 0.2),
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
