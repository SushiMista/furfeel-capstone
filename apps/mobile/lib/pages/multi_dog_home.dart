import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/friendly_time.dart';
import '../util/motion.dart';
import '../widgets/dog_avatar.dart';
import '../widgets/skeletons.dart';
import '../widgets/stress_pill.dart';
import 'dog_detail_page.dart';

/// Multi-dog Home (QA item 9): one glanceable card per owned dog — photo,
/// name, stress pill / wellness score, a key vital, battery, last-updated.
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final overviews = _overviews;
    if (overviews == null && _error == null) return const HomeSkeleton();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          const _PackGreeting(),
          const SizedBox(height: FurFeelTokens.space3),
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
                  onTap: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => DogDetailPage(
                            repository: widget.repository,
                            dog: overview.dog,
                          ),
                        ),
                      )
                      .then((_) => _load()),
                ).entrance(context, index: 1 + i),
              ),
        ],
      ),
    );
  }
}

class _PackGreeting extends StatelessWidget {
  const _PackGreeting();

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
        Text('Here\'s how your pack is doing',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ).entrance(context);
  }
}

/// One glanceable dog card. Word + color everywhere, never color alone.
class DogOverviewCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final settings = SettingsScope.of(context);
    final dog = overview.dog;
    final level = overview.classification?.stressLevel;
    final reading = overview.reading;
    final wellness = overview.wellness;
    final battery = overview.device?.batteryPercent;
    final batteryLow = overview.device?.isBatteryLow ?? false;

    return PressScale(
      child: Material(
        color: FurFeelTokens.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            decoration: BoxDecoration(
              border: Border.all(color: FurFeelTokens.hairline),
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
              boxShadow: FurFeelTokens.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DogAvatar(
                      dog: dog,
                      repository: repository,
                      backgroundColor: level != null
                          ? stressLevelSoftBg(level)
                          : FurFeelTokens.brandSoft,
                    ),
                    const SizedBox(width: FurFeelTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dog.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          if (dog.breed != null)
                            Text(dog.breed!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (level != null)
                      StressPill(level: level)
                    else
                      Text('No data yet', style: textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: FurFeelTokens.space3),
                Row(
                  children: [
                    if (wellness != null) ...[
                      _MiniStat(
                        icon: Icons.favorite_border,
                        label: 'Wellness',
                        value: '${wellness.score}',
                      ),
                      const SizedBox(width: FurFeelTokens.space4),
                    ],
                    if (reading?.heartRateBpm != null) ...[
                      _MiniStat(
                        icon: Icons.monitor_heart_outlined,
                        label: 'Heart',
                        value: '${reading!.heartRateBpm} bpm',
                      ),
                      const SizedBox(width: FurFeelTokens.space4),
                    ] else if (reading?.bodyTemperatureC != null) ...[
                      _MiniStat(
                        icon: Icons.thermostat_outlined,
                        label: 'Temp',
                        value:
                            '${settings.formatTemperature(reading!.bodyTemperatureC)}${settings.temperatureUnitLabel}',
                      ),
                      const SizedBox(width: FurFeelTokens.space4),
                    ],
                    if (battery != null)
                      _MiniStat(
                        icon: batteryLow ? Icons.battery_alert : Icons.battery_full,
                        label: 'Battery',
                        value: '$battery%',
                        valueColor:
                            batteryLow ? FurFeelTokens.statusHighOwner : null,
                      ),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 18, color: FurFeelTokens.inkMuted),
                  ],
                ),
                const SizedBox(height: FurFeelTokens.space2),
                Text(
                  reading != null
                      ? 'Updated ${friendlyTimestamp(reading.capturedAt)}'
                      : 'Waiting for the first reading',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
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
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: FurFeelTokens.inkMuted),
        const SizedBox(width: FurFeelTokens.space1),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: FurFeelTokens.inkMuted,
                )),
            Text(value,
                style: TextStyle(
                  fontSize: FurFeelTokens.typeCaptionSize,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? FurFeelTokens.ink,
                )),
          ],
        ),
      ],
    );
  }
}
