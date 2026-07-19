// GENERATED from packages/shared/classifier_config.json — do not edit by hand.
// Regenerate with: node packages/shared/scripts/generate_classifier_bands.mjs
// Every value here is provisional and vet-tunable at the source config.

/// Global default baselines (classifier_config.json global_baselines).
const kGlobalRestingHr = 90;
const kGlobalRestingRr = 24;

/// Status-band floors. Elevated/High = the rule-v1 scoring tier floors
/// (what starts to score / scores harder); Low = biometric_status_bands.
const kHrRatioLowBelow = 0.7;
const kHrRatioElevatedAt = 1.15;
const kHrRatioHighAt = 1.35;

const kRrRatioLowBelow = 0.5;
const kRrRatioElevatedAt = 1.3;
const kRrRatioHighAt = 1.8;

const kTempLowBelowC = 37.5;
const kTempElevatedAtC = 39.2;
const kTempHighAtC = 39.7;

/// Environment thresholds (environmental_amplifier / context_rules).
const kHotAmbientAboveC = 32;
const kHotHumidityAbovePercent = 80;
const kColdAmbientBelowC = 8;

/// "Restless" floor for Care Insights combinations = the motion tier-1 floor.
const kRestlessMotionAt = 0.6;
