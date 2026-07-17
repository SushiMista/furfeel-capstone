import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardrail test (CLAUDE.md / QA item 18): owner-facing copy stays
/// observational. It never diagnoses and never makes causal medical claims.
///
/// Scans the sources that carry the new care/alert/consent copy. "diagnos..."
/// is allowed only in explicit negations ("not a diagnosis", "never
/// diagnosis") — which we WANT the copy to say.
void main() {
  const files = [
    // New combination care tips (vet-editable seeds).
    '../../supabase/migrations/20260717100000_battery_consents_media_threads_care_combos.sql',
    // Friendly alert copy generated server-side.
    '../../services/edge/alerts/rules.ts',
    // App-side owner copy added in this pass.
    'lib/insights/biometrics.dart',
    'lib/pages/consent_page.dart',
    'lib/pages/media_thread_page.dart',
    'lib/pages/detailed_log_page.dart',
    'lib/pages/multi_dog_home.dart',
    'lib/widgets/wellness_card.dart',
    'lib/util/exports.dart',
    // Owner-delight pass copy.
    'lib/insights/owner_moments.dart',
    'lib/widgets/setup_checklist_card.dart',
    'lib/widgets/day_timeline.dart',
  ];

  // Clinical / causal language that must never appear in owner copy.
  const bannedOutright = [
    'disease',
    'prescri',
    'medication',
    'symptom',
    'infect',
    'illness',
    'caused by',
    'because of',
    'due to',
  ];

  test('new owner-facing copy contains no diagnosis or causal-claim language', () {
    final failures = <String>[];
    for (final path in files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'missing $path');
      final text = file.readAsStringSync().toLowerCase();

      for (final banned in bannedOutright) {
        if (text.contains(banned)) failures.add('$path contains "$banned"');
      }

      // 'diagnos' only within a negation ("not/never ... diagnosis").
      for (final match in 'diagnos'.allMatches(text)) {
        final start = match.start < 40 ? 0 : match.start - 40;
        final context = text.substring(start, match.start);
        if (!context.contains('not') && !context.contains('never')) {
          failures.add('$path uses "diagnos" without negation near "$context"');
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
