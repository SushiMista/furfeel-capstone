import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/insights/biometric_bands.g.dart';

/// Staleness guard: biometric_bands.g.dart is generated from
/// packages/shared/classifier_config.json. If someone tunes the config without
/// running `node packages/shared/scripts/generate_classifier_bands.mjs`, this
/// test fails instead of the app quietly drifting from the classifier
/// (QA assumption 4, now retired).
void main() {
  test('generated biometric bands match classifier_config.json', () {
    // flutter test runs with CWD at the package root (apps/mobile).
    final cfg = jsonDecode(
      File('../../packages/shared/classifier_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final rules = cfg['scoring_rules'] as Map<String, dynamic>;
    final bands = cfg['biometric_status_bands'] as Map<String, dynamic>;
    num tierMin(String rule, int tier) =>
        (((rules[rule] as Map)['tiers'] as List)[tier] as Map)['min'] as num;

    final baselines = cfg['global_baselines'] as Map<String, dynamic>;
    expect(kGlobalRestingHr, baselines['heart_rate_bpm']);
    expect(kGlobalRestingRr, baselines['respiratory_rate_bpm']);

    expect(kHrRatioLowBelow, bands['hr_ratio_low_below']);
    expect(kHrRatioElevatedAt, tierMin('heart_rate_elevated', 0));
    expect(kHrRatioHighAt, tierMin('heart_rate_elevated', 1));

    expect(kRrRatioLowBelow, bands['rr_ratio_low_below']);
    expect(kRrRatioElevatedAt, tierMin('respiratory_elevated', 0));
    expect(kRrRatioHighAt, tierMin('respiratory_elevated', 1));

    expect(kTempLowBelowC, bands['body_temperature_c_low_below']);
    expect(kTempElevatedAtC, tierMin('body_temperature', 0));
    expect(kTempHighAtC, tierMin('body_temperature', 1));

    final amp = rules['environmental_amplifier'] as Map<String, dynamic>;
    expect(kHotAmbientAboveC, amp['ambient_temperature_c_above']);
    expect(kHotHumidityAbovePercent, amp['humidity_percent_above']);
    expect(
      kColdAmbientBelowC,
      ((cfg['context_rules'] as Map)['environmental_cold']
          as Map)['ambient_temperature_c_below'],
    );

    expect(kRestlessMotionAt, tierMin('motion_restlessness', 0));
  });
}
