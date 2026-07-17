import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// Today's wellness score + activity/rest balance (QA item 16), from the
/// dog_wellness_score RPC. Provisional engineering score — the card says so.
class WellnessCard extends StatefulWidget {
  const WellnessCard({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  State<WellnessCard> createState() => _WellnessCardState();
}

class _WellnessCardState extends State<WellnessCard> {
  WellnessSnapshot? _wellness;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WellnessCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dog.id != widget.dog.id) {
      setState(() {
        _wellness = null;
        _loaded = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final wellness =
          await widget.repository.fetchWellness(widget.dog.id, DateTime.now());
      if (mounted) {
        setState(() {
          _wellness = wellness;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Color _scoreColor(int score) => score >= 70
      ? FurFeelTokens.statusCalmFg
      : score >= 40
          ? FurFeelTokens.statusMildFg
          : FurFeelTokens.statusHighOwner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final wellness = _wellness;
    // No data (or still loading): stay quiet rather than showing a zero.
    if (!_loaded || wellness == null) return const SizedBox.shrink();

    final color = _scoreColor(wellness.score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: wellness.score / 100,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: FurFeelTokens.surfaceAlt,
                  ),
                  Center(
                    child: Text(
                      '${wellness.score}',
                      style: TextStyle(
                        fontSize: FurFeelTokens.typeH2Size,
                        fontWeight: FontWeight.w700,
                        color: FurFeelTokens.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: FurFeelTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wellness today',
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: FurFeelTokens.space1),
                  _BalanceBar(
                    activePercent: wellness.activePercent,
                    restPercent: wellness.restPercent,
                  ),
                  const SizedBox(height: FurFeelTokens.space1),
                  Text(
                    'Active ${wellness.activePercent.round()}% · '
                    'Resting ${wellness.restPercent.round()}% · '
                    'Calm ${wellness.calmPercent.round()}%',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text('An engineering estimate, not a medical score.',
                      style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim stacked bar: active share vs resting share vs in-between.
class _BalanceBar extends StatelessWidget {
  const _BalanceBar({required this.activePercent, required this.restPercent});

  final double activePercent;
  final double restPercent;

  @override
  Widget build(BuildContext context) {
    final active = (activePercent / 100).clamp(0.0, 1.0);
    final rest = (restPercent / 100).clamp(0.0, 1.0 - active);
    final between = (1 - active - rest).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (active > 0)
              Expanded(
                flex: (active * 1000).round(),
                child: Container(color: FurFeelTokens.brand),
              ),
            if (between > 0)
              Expanded(
                flex: (between * 1000).round(),
                child: Container(color: FurFeelTokens.surfaceAlt),
              ),
            if (rest > 0)
              Expanded(
                flex: (rest * 1000).round(),
                child: Container(color: FurFeelTokens.accent),
              ),
          ],
        ),
      ),
    );
  }
}
