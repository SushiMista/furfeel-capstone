import { defaultConfig } from "./config.ts";
import type {
  Baselines,
  ClassificationResult,
  ClassifierConfig,
  ScoringTier,
  StressLevel,
  TelemetryFeatures,
} from "./types.ts";

function matchTier(value: number, tiers: ScoringTier[]): ScoringTier | null {
  for (const tier of tiers) {
    if (value >= tier.min && (tier.max === null || value < tier.max)) {
      return tier;
    }
  }
  return null;
}

/** Strictly increasing check over the last `windowSize` prior scores, oldest-to-newest. */
function isRisingTrend(recentScores: number[], windowSize: number): boolean {
  if (recentScores.length < windowSize) return false;
  const window = recentScores.slice(-windowSize);
  for (let i = 1; i < window.length; i++) {
    if (window[i] <= window[i - 1]) return false;
  }
  return true;
}

function scoreToLevel(
  score: number,
  thresholds: ClassifierConfig["level_thresholds"],
): StressLevel {
  for (const level of ["calm", "mild", "moderate", "high"] as const) {
    const { min, max } = thresholds[level];
    if (score >= min && (max === null || score <= max)) return level;
  }
  // Scores can't fall below `calm`'s min (0) or above `high`'s unbounded max,
  // so every value is covered above; this is unreachable in practice.
  return "high";
}

/**
 * rule-v1 stress classifier (docs/08 AI Classification Pipeline).
 * Pure function: no I/O, no Supabase/Deno runtime dependencies. All thresholds and
 * baselines come from packages/shared/classifier_config.json, never hardcoded here.
 *
 * @param reading Sanitized telemetry features (null = missing or failed docs/07 validation).
 * @param baselines Per-dog baselines where available, else global defaults (caller's responsibility).
 * @param recentScores The dog's prior stress_classifications.score values, oldest-to-newest,
 *   most recent last (used for the rising-trend rule).
 */
export function classifyStress(
  reading: TelemetryFeatures,
  baselines: Baselines,
  recentScores: number[] = [],
  config: ClassifierConfig = defaultConfig,
): ClassificationResult {
  const rules = config.scoring_rules;
  let score = 0;
  const reasons: string[] = [];

  if (reading.heart_rate_bpm !== null && baselines.heart_rate_bpm > 0) {
    const hrRatio = reading.heart_rate_bpm / baselines.heart_rate_bpm;
    const tier = matchTier(hrRatio, rules.heart_rate_elevated.tiers);
    if (tier) {
      score += tier.points;
      reasons.push(tier.reason);
    }
  }

  if (reading.respiratory_rate_bpm !== null && baselines.respiratory_rate_bpm > 0) {
    const rrRatio = reading.respiratory_rate_bpm / baselines.respiratory_rate_bpm;
    const tier = matchTier(rrRatio, rules.respiratory_elevated.tiers);
    if (tier) {
      score += tier.points;
      reasons.push(tier.reason);
    }
  }

  if (reading.body_temperature_c !== null) {
    const tier = matchTier(reading.body_temperature_c, rules.body_temperature.tiers);
    if (tier) {
      score += tier.points;
      reasons.push(tier.reason);
    }
  }

  if (reading.motion_activity !== null) {
    const tier = matchTier(reading.motion_activity, rules.motion_restlessness.tiers);
    if (tier) {
      score += tier.points;
      reasons.push(tier.reason);
    }
  }

  const postureRule = rules.posture_moving_with_high_motion;
  if (
    reading.posture === postureRule.posture &&
    reading.motion_activity !== null &&
    reading.motion_activity >= postureRule.motion_activity_min
  ) {
    score += postureRule.points;
    reasons.push(postureRule.reason);
  }

  const envRule = rules.environmental_amplifier;
  const ambientHot = reading.ambient_temperature_c !== null &&
    reading.ambient_temperature_c > envRule.ambient_temperature_c_above;
  const humid = reading.humidity_percent !== null &&
    reading.humidity_percent > envRule.humidity_percent_above;
  if (ambientHot || humid) {
    score += envRule.points;
    reasons.push(envRule.reason);
  }

  const trendRule = rules.rising_trend;
  if (isRisingTrend(recentScores, trendRule.window_size)) {
    score += trendRule.points;
    reasons.push(trendRule.reason);
  }

  // Context-only: cold never changes the score (docs/08 scores heat, not cold)
  // but the reason code drives Care Insights combinations and the owner "why".
  const coldRule = config.context_rules.environmental_cold;
  if (
    reading.ambient_temperature_c !== null &&
    reading.ambient_temperature_c < coldRule.ambient_temperature_c_below
  ) {
    reasons.push(coldRule.reason);
  }

  return {
    stress_level: scoreToLevel(score, config.level_thresholds),
    score,
    reasons,
    model_version: config.model_version,
  };
}
