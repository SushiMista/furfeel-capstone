import 'package:flutter/material.dart';

import '../insights/owner_moments.dart';
import '../theme/furfeel_tokens.dart';

/// Guided setup checklist (owner-delight pass): shows on Home until the
/// harness is paired and the first reading lands, so a new owner always knows
/// the next step instead of staring at empty cards.
class SetupChecklistCard extends StatelessWidget {
  const SetupChecklistCard({
    super.key,
    required this.dogName,
    required this.progress,
    required this.onPairHarness,
    required this.onLinkClinic,
  });

  final String dogName;
  final Map<SetupStep, bool> progress;
  final VoidCallback onPairHarness;
  final VoidCallback onLinkClinic;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final done = progress.values.where((v) => v).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rounded, size: 18, color: context.ff.brand),
                const SizedBox(width: FurFeelTokens.space2),
                Expanded(
                  child: Text('FINISH SETTING UP $dogName'.toUpperCase(),
                      style: textTheme.labelSmall),
                ),
                Text('$done of ${progress.length}', style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: FurFeelTokens.space2),
            for (final entry in progress.entries)
              InkWell(
                onTap: switch (entry.key) {
                  _ when entry.value => null,
                  SetupStep.pairHarness => onPairHarness,
                  SetupStep.linkClinic => onLinkClinic,
                  SetupStep.firstReading => null,
                },
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: FurFeelTokens.space2),
                  child: Row(
                    children: [
                      Icon(
                        entry.value
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: entry.value
                            ? context.ff.statusCalmFg
                            : context.ff.inkMuted,
                      ),
                      const SizedBox(width: FurFeelTokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key.title,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: entry.value
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: entry.value
                                    ? context.ff.inkMuted
                                    : context.ff.ink,
                              ),
                            ),
                            if (!entry.value)
                              Text(entry.key.subtitle, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (!entry.value && entry.key != SetupStep.firstReading)
                        Icon(Icons.chevron_right,
                            size: 18, color: context.ff.inkMuted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
