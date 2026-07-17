// Canonical definitions live in packages/shared/types (single source of truth across
// edge functions, the simulator, and the dashboard). Re-exported here so existing
// classifier imports (./types.ts) don't need to change.
import type { Posture } from "../../../packages/shared/types/telemetry.ts";
import type { StressLevel } from "../../../packages/shared/types/stress.ts";
export type { Posture } from "../../../packages/shared/types/telemetry.ts";
export type { StressLevel } from "../../../packages/shared/types/stress.ts";

/** Sanitized telemetry values fed to the classifier. A null field means the value was
 * missing or failed docs/07 range validation — either way the classifier skips rules
 * that depend on it (docs/07: "the classifier skips rules for null fields"). */
export interface TelemetryFeatures {
  heart_rate_bpm: number | null;
  respiratory_rate_bpm: number | null;
  body_temperature_c: number | null;
  motion_activity: number | null;
  posture: Posture | null;
  ambient_temperature_c: number | null;
  humidity_percent: number | null;
}

/** Resolved per-dog (or global-default) resting reference values. */
export interface Baselines {
  heart_rate_bpm: number;
  respiratory_rate_bpm: number;
  body_temperature_c: number;
  motion_activity: number;
}

export interface ClassificationResult {
  stress_level: StressLevel;
  score: number;
  reasons: string[];
  model_version: string;
}

export interface ScoringTier {
  min: number;
  max: number | null;
  points: number;
  reason: string;
}

export interface ScoringRule {
  input: "hr_ratio" | "rr_ratio" | "body_temperature_c" | "motion_activity";
  tiers: ScoringTier[];
}

export interface PostureRule {
  posture: Posture;
  motion_activity_min: number;
  points: number;
  reason: string;
}

export interface EnvironmentalRule {
  ambient_temperature_c_above: number;
  humidity_percent_above: number;
  points: number;
  reason: string;
}

export interface TrendRule {
  window_size: number;
  points: number;
  reason: string;
}

/** Context-only rule: contributes a reason code but never any points. */
export interface ColdContextRule {
  ambient_temperature_c_below: number;
  reason: string;
}

export interface LevelThreshold {
  min: number;
  max: number | null;
}

export interface ValidationRange {
  min: number;
  max: number;
}

export interface ClassifierConfig {
  model_version: string;
  global_baselines: {
    heart_rate_bpm: number;
    respiratory_rate_bpm: number;
    body_temperature_c: number;
    motion_activity: number;
  };
  scoring_rules: {
    heart_rate_elevated: ScoringRule;
    respiratory_elevated: ScoringRule;
    body_temperature: ScoringRule;
    motion_restlessness: ScoringRule;
    posture_moving_with_high_motion: PostureRule;
    environmental_amplifier: EnvironmentalRule;
    rising_trend: TrendRule;
  };
  context_rules: {
    environmental_cold: ColdContextRule;
  };
  device_alerts: {
    low_battery_percent: number;
  };
  level_thresholds: {
    calm: LevelThreshold;
    mild: LevelThreshold;
    moderate: LevelThreshold;
    high: LevelThreshold;
  };
  validation_ranges: {
    heart_rate_bpm: ValidationRange;
    body_temperature_c: ValidationRange;
    respiratory_rate_bpm: ValidationRange;
    motion_activity: ValidationRange;
    ambient_temperature_c: ValidationRange;
    humidity_percent: ValidationRange;
    battery_percent: ValidationRange;
    captured_at_max_skew_hours: number;
  };
}
