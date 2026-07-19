#!/usr/bin/env node
// Generates apps/mobile/lib/insights/biometric_bands.g.dart from
// packages/shared/classifier_config.json so the owner-facing status bands can
// never drift from the classifier's own thresholds (they used to be mirrored
// by hand — QA assumption 4). Elevated/High floors come straight from the
// scoring tiers; only the Low floors are band-specific config.
// Run from anywhere: node packages/shared/scripts/generate_classifier_bands.mjs

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const cfg = JSON.parse(readFileSync(join(here, "..", "classifier_config.json"), "utf8"));

const num = (v) => (Number.isInteger(v) ? `${v}` : `${v}`);
const rules = cfg.scoring_rules;
const bands = cfg.biometric_status_bands;

const out = `// GENERATED from packages/shared/classifier_config.json — do not edit by hand.
// Regenerate with: node packages/shared/scripts/generate_classifier_bands.mjs
// Every value here is provisional and vet-tunable at the source config.

/// Global default baselines (classifier_config.json global_baselines).
const kGlobalRestingHr = ${num(cfg.global_baselines.heart_rate_bpm)};
const kGlobalRestingRr = ${num(cfg.global_baselines.respiratory_rate_bpm)};

/// Status-band floors. Elevated/High = the rule-v1 scoring tier floors
/// (what starts to score / scores harder); Low = biometric_status_bands.
const kHrRatioLowBelow = ${num(bands.hr_ratio_low_below)};
const kHrRatioElevatedAt = ${num(rules.heart_rate_elevated.tiers[0].min)};
const kHrRatioHighAt = ${num(rules.heart_rate_elevated.tiers[1].min)};

const kRrRatioLowBelow = ${num(bands.rr_ratio_low_below)};
const kRrRatioElevatedAt = ${num(rules.respiratory_elevated.tiers[0].min)};
const kRrRatioHighAt = ${num(rules.respiratory_elevated.tiers[1].min)};

const kTempLowBelowC = ${num(bands.body_temperature_c_low_below)};
const kTempElevatedAtC = ${num(rules.body_temperature.tiers[0].min)};
const kTempHighAtC = ${num(rules.body_temperature.tiers[1].min)};

/// Environment thresholds (environmental_amplifier / context_rules).
const kHotAmbientAboveC = ${num(rules.environmental_amplifier.ambient_temperature_c_above)};
const kHotHumidityAbovePercent = ${num(rules.environmental_amplifier.humidity_percent_above)};
const kColdAmbientBelowC = ${num(cfg.context_rules.environmental_cold.ambient_temperature_c_below)};

/// "Restless" floor for Care Insights combinations = the motion tier-1 floor.
const kRestlessMotionAt = ${num(rules.motion_restlessness.tiers[0].min)};
`;

const dartPath = join(here, "..", "..", "..", "apps", "mobile", "lib", "insights", "biometric_bands.g.dart");
writeFileSync(dartPath, out);
console.log(`wrote ${dartPath}`);
