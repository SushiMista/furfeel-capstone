import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../widgets/stress_pill.dart';

/// Care tips library (owner-delight pass): every piece of vet-editable
/// guidance in one browsable place — per stress level plus the situation
/// (combination) tips — so owners can read ahead, not just when stressed.
class CareTipsPage extends StatefulWidget {
  const CareTipsPage({super.key, required this.repository});

  final FurFeelRepository repository;

  @override
  State<CareTipsPage> createState() => _CareTipsPageState();
}

class _CareTipsPageState extends State<CareTipsPage> {
  List<CareGuidance>? _guidance;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.repository.fetchCareGuidance();
      if (mounted) {
        setState(() {
          _guidance = rows;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn\'t load the tips. Pull to retry.');
      }
    }
  }

  /// Friendly headline per situation key (matches care_guidance.context_key).
  static String situationLabel(String contextKey) => switch (contextKey) {
        'cold_stressed' => 'Cold day, tense dog',
        'hot_stressed' => 'Hot day, stressed dog',
        'panting_hot' => 'Panting in the heat',
        'restless_high_hr' => 'Restless with a racing heart',
        'cold_calm' => 'Chilly but comfortable',
        'hot_calm' => 'Warm day, relaxed dog',
        _ => contextKey.replaceAll('_', ' '),
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final guidance = _guidance;
    final levelRows = <CareGuidance>[];
    final situationRows = <CareGuidance>[];
    for (final row in guidance ?? const <CareGuidance>[]) {
      (row.contextKey == null ? levelRows : situationRows).add(row);
    }
    levelRows.sort((a, b) =>
        (a.stressLevel?.index ?? 0).compareTo(b.stressLevel?.index ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Care tips')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(FurFeelTokens.space4),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: FurFeelTokens.space3),
                child: Text(_error!,
                    style: TextStyle(color: context.ff.statusHighOwner)),
              ),
            Text(
              'Written by care teams for everyday situations. General guidance '
              'to talk over with your clinic — never a diagnosis.',
              style: textTheme.bodySmall,
            ).entrance(context),
            if (levelRows.isNotEmpty) ...[
              const SizedBox(height: FurFeelTokens.space4),
              Text('BY STRESS LEVEL', style: textTheme.labelSmall),
              const SizedBox(height: FurFeelTokens.space2),
              for (final (i, row) in levelRows.indexed)
                _TipCard(
                  leading: row.stressLevel == null
                      ? null
                      : StressPill(level: row.stressLevel!),
                  title: row.title,
                  body: row.body,
                ).entrance(context, index: 1 + i),
            ],
            if (situationRows.isNotEmpty) ...[
              const SizedBox(height: FurFeelTokens.space4),
              Text('BY SITUATION', style: textTheme.labelSmall),
              const SizedBox(height: FurFeelTokens.space2),
              for (final (i, row) in situationRows.indexed)
                _TipCard(
                  eyebrow: situationLabel(row.contextKey!),
                  title: row.title,
                  body: row.body,
                ).entrance(context, index: 1 + levelRows.length + i),
            ],
            const SizedBox(height: FurFeelTokens.space4),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.title, required this.body, this.leading, this.eyebrow});

  final Widget? leading;
  final String? eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: FurFeelTokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(height: FurFeelTokens.space2),
            ],
            if (eyebrow != null) ...[
              Text(eyebrow!.toUpperCase(),
                  style: textTheme.labelSmall
                      ?.copyWith(color: context.ff.warm)),
              const SizedBox(height: FurFeelTokens.space1),
            ],
            Text(title,
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: FurFeelTokens.space1),
            Text(body, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
