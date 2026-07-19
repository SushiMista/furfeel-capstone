/// Biometric status labeling + combination care-insight selection (QA pass).
///
/// Pure functions, unit-tested. Wording is strictly observational — a status
/// word describes where a number sits relative to the dog's typical resting
/// range, never what it means medically.
///
/// Thresholds mirror packages/shared/classifier_config.json (rule-v1 tiers and
/// the environmental amplifier / cold context rules). There is no Dart codegen
/// from that JSON yet, so keep these constants in sync by hand — every value
/// here is provisional and vet-tunable at the source config.
library;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// Plain-language status for a vital, from Low to High.
enum VitalStatus {
  low('Low'),
  normal('Normal'),
  elevated('Elevated'),
  high('High');

  const VitalStatus(this.label);
  final String label;
}

/// Token color for a status (word + color, never color alone — docs/19 §9).
Color vitalStatusColor(BuildContext context, VitalStatus status) => switch (status) {
      // Low is a heads-up, not "good": amber like mild.
      VitalStatus.low => context.ff.statusMildFg,
      VitalStatus.normal => context.ff.statusCalmFg,
      VitalStatus.elevated => context.ff.statusModerateFg,
      VitalStatus.high => context.ff.statusHighOwner,
    };

// Global default baselines (classifier_config.json global_baselines).
const _globalRestingHr = 90;
const _globalRestingRr = 24;

/// Heart-rate status from the dog's baseline (dog_baselines row when the
/// clinic set one, else the global default). Ratio bands align with the
/// rule-v1 hr tiers: >=1.15 scores, >=1.35 scores harder.
VitalStatus? heartRateStatus(int? bpm, DogBaseline? baseline) {
  if (bpm == null) return null;
  final resting = baseline?.restingHeartRateBpm ?? _globalRestingHr;
  final ratio = bpm / resting;
  if (ratio < 0.7) return VitalStatus.low;
  if (ratio < 1.15) return VitalStatus.normal;
  if (ratio < 1.35) return VitalStatus.elevated;
  return VitalStatus.high;
}

/// Respiratory-rate status; bands align with the rule-v1 rr tiers (1.3 / 1.8).
VitalStatus? respiratoryStatus(int? bpm, DogBaseline? baseline) {
  if (bpm == null) return null;
  final resting = baseline?.restingRespiratoryRateBpm ?? _globalRestingRr;
  final ratio = bpm / resting;
  if (ratio < 0.5) return VitalStatus.low;
  if (ratio < 1.3) return VitalStatus.normal;
  if (ratio < 1.8) return VitalStatus.elevated;
  return VitalStatus.high;
}

/// Body-temperature status. Absolute bands (rule-v1 scores 39.2/39.7; the
/// typical resting range 37.5-39.2 matches the vital detail screen).
VitalStatus? temperatureStatus(double? celsius) {
  if (celsius == null) return null;
  if (celsius < 37.5) return VitalStatus.low;
  if (celsius < 39.2) return VitalStatus.normal;
  if (celsius < 39.7) return VitalStatus.elevated;
  return VitalStatus.high;
}

/// One-line owner phrase: "Heart rate 92 bpm — Normal for Biscuit".
String vitalStatusPhrase(String vitalLabel, String value, VitalStatus status, String dogName) =>
    '$vitalLabel $value — ${status.label} for $dogName';

// Environment thresholds (classifier_config.json environmental_amplifier /
// context_rules.environmental_cold).
const _hotAmbientC = 32.0;
const _hotHumidityPercent = 80.0;
const _coldAmbientC = 8.0;

bool _isHot(TelemetryReading r) =>
    (r.ambientTemperatureC != null && r.ambientTemperatureC! > _hotAmbientC) ||
    (r.humidityPercent != null && r.humidityPercent! > _hotHumidityPercent);

bool _isCold(TelemetryReading r) =>
    r.ambientTemperatureC != null && r.ambientTemperatureC! < _coldAmbientC;

/// Picks the active combination context for Care Insights, or null when no
/// combination applies (fall back to the per-level guidance). Keys must match
/// the seeded care_guidance.context_key values. Order = specificity: the
/// stressed combinations outrank the calm comfort tips.
String? careContextKey({
  required StressLevel? level,
  required TelemetryReading? reading,
  DogBaseline? baseline,
}) {
  if (reading == null) return null;
  final stressed = level != null && level != StressLevel.calm;
  final rr = respiratoryStatus(reading.respiratoryRateBpm, baseline);
  final hr = heartRateStatus(reading.heartRateBpm, baseline);
  final restless = (reading.motionActivity ?? 0) >= 0.6;

  if (stressed && _isCold(reading)) return 'cold_stressed';
  if (_isHot(reading) && rr == VitalStatus.high) return 'panting_hot';
  if (stressed && _isHot(reading)) return 'hot_stressed';
  if (restless && (hr == VitalStatus.elevated || hr == VitalStatus.high)) {
    return 'restless_high_hr';
  }
  if (_isCold(reading)) return 'cold_calm';
  if (_isHot(reading)) return 'hot_calm';
  return null;
}

/// Picks the guidance to show: a context (combination) row wins over the
/// per-level default, and within each kind a clinic-specific row wins over
/// the global one (docs/09 care_guidance).
CareGuidance? selectGuidance(
  List<CareGuidance> rows, {
  required StressLevel? level,
  required String? contextKey,
  required String? clinicId,
}) {
  CareGuidance? pick(bool Function(CareGuidance) matches) {
    CareGuidance? global;
    for (final row in rows) {
      if (!matches(row)) continue;
      if (clinicId != null && row.clinicId == clinicId) return row;
      if (row.clinicId == null) global = row;
    }
    return global;
  }

  if (contextKey != null) {
    final contextual = pick((r) => r.contextKey == contextKey);
    if (contextual != null) return contextual;
  }
  if (level == null) return null;
  return pick((r) => r.contextKey == null && r.stressLevel == level);
}
