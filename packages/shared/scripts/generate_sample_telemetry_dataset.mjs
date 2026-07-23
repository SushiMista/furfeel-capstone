#!/usr/bin/env node
// Generates docs/Sample Telemetry Dataset.csv: raw payloads shaped exactly like
// docs/07 Sensor Data Pipeline's "Final Telemetry Payload" (the same schema the
// ESP32 harness / firmware/simulator send), across three illustrative dog size
// classes, sweeping calm -> high -> back to calm, plus deliberate validation-
// range violations (docs/07) so the sheet doubles as expert-review material for
// docs/13 Validation and Expert Review Checklist ("Rule-based threshold logic").
//
// Reference columns (expected_score/expected_level/fired_rules) are NOT part of
// the device payload -- they're rule-v1's own output, included so a reviewer can
// see, for each row, exactly which classifier_config.json thresholds fired.
// Every number here is the CURRENT PROVISIONAL config, not a new invented value
// (CLAUDE.md: don't invent thresholds silently).
//
// Run from anywhere: node packages/shared/scripts/generate_sample_telemetry_dataset.mjs

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const cfg = JSON.parse(readFileSync(join(here, "..", "classifier_config.json"), "utf8"));
const outPath = join(here, "..", "..", "..", "docs", "Sample Telemetry Dataset.csv");

// Three illustrative size classes (docs has no size_class column yet -- these
// are example per-dog baselines, the same mechanism dog_baselines already
// supports, just spelled out here for a concrete worked dataset).
const DOGS = [
  { name: "Mochi", breed: "Shiba Inu", size_class: "small", weight_kg: 9.8,
    baseline: { heart_rate_bpm: 110, respiratory_rate_bpm: 26, body_temperature_c: 38.6 } },
  { name: "Rio", breed: "Border Collie", size_class: "medium", weight_kg: 18.0,
    baseline: cfg.global_baselines }, // medium ~= the global default persona
  { name: "Duke", breed: "Great Dane", size_class: "large", weight_kg: 55.0,
    baseline: { heart_rate_bpm: 72, respiratory_rate_bpm: 18, body_temperature_c: 38.4 } },
];

function lerp(a, b, t) { return a + (b - a) * t; }
function jitter(value, amount, rng) { return value + (rng() * 2 - 1) * amount; }
function clamp(value, min, max) { return Math.min(max, Math.max(min, value)); }
function round(value, places) {
  const f = 10 ** places;
  return Math.round(value * f) / f;
}

// Deterministic RNG (mulberry32) so the sheet is reproducible across runs --
// a validation document that changes every regeneration isn't reviewable.
function mulberry32(seed) {
  let a = seed;
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Same shape as classifier_config.json.scoring_rules, evaluated directly
// against its tiers -- no re-derivation, so this can never drift from what
// the edge function actually scores.
function scoreReading(reading, baseline, prior3Scores) {
  const reasons = [];
  let score = 0;
  const tier = (ratioOrValue, tiers) =>
    tiers.find((t) => ratioOrValue >= t.min && (t.max === null || ratioOrValue < t.max));

  if (reading.heart_rate_bpm != null && baseline.heart_rate_bpm) {
    const hit = tier(reading.heart_rate_bpm / baseline.heart_rate_bpm, cfg.scoring_rules.heart_rate_elevated.tiers);
    if (hit) { score += hit.points; reasons.push(hit.reason); }
  }
  if (reading.respiratory_rate_bpm != null && baseline.respiratory_rate_bpm) {
    const hit = tier(reading.respiratory_rate_bpm / baseline.respiratory_rate_bpm, cfg.scoring_rules.respiratory_elevated.tiers);
    if (hit) { score += hit.points; reasons.push(hit.reason); }
  }
  if (reading.body_temperature_c != null) {
    const hit = tier(reading.body_temperature_c, cfg.scoring_rules.body_temperature.tiers);
    if (hit) { score += hit.points; reasons.push(hit.reason); }
  }
  if (reading.motion_activity != null) {
    const hit = tier(reading.motion_activity, cfg.scoring_rules.motion_restlessness.tiers);
    if (hit) { score += hit.points; reasons.push(hit.reason); }
    const pr = cfg.scoring_rules.posture_moving_with_high_motion;
    if (reading.posture === pr.posture && reading.motion_activity >= pr.motion_activity_min) {
      score += pr.points; reasons.push(pr.reason);
    }
  }
  const ea = cfg.scoring_rules.environmental_amplifier;
  if (reading.ambient_temperature_c > ea.ambient_temperature_c_above ||
      reading.humidity_percent > ea.humidity_percent_above) {
    score += ea.points; reasons.push(ea.reason);
  }
  if (prior3Scores.length === 3 && prior3Scores[0] < prior3Scores[1] && prior3Scores[1] < prior3Scores[2]) {
    score += cfg.scoring_rules.rising_trend.points;
    reasons.push(cfg.scoring_rules.rising_trend.reason);
  }

  const lt = cfg.level_thresholds;
  const level = score <= lt.calm.max ? "calm"
    : score <= lt.mild.max ? "mild"
    : score <= lt.moderate.max ? "moderate"
    : "high";
  return { score, level, reasons };
}

function buildSweepRows(dog, rng, startTick) {
  const CALM = { heart_rate_bpm: dog.baseline.heart_rate_bpm, respiratory_rate_bpm: dog.baseline.respiratory_rate_bpm, body_temperature_c: dog.baseline.body_temperature_c, motion_activity: 0.25 };
  const HIGH = { heart_rate_bpm: Math.round(dog.baseline.heart_rate_bpm * 1.7), respiratory_rate_bpm: Math.round(dog.baseline.respiratory_rate_bpm * 1.9), body_temperature_c: dog.baseline.body_temperature_c + 1.1, motion_activity: 0.85 };
  const TICKS = 12; // calm -> high
  const rows = [];
  const recentScores = [];
  for (let i = 0; i <= TICKS; i++) {
    const up = i <= TICKS / 2;
    const t = clamp((up ? i : TICKS - i) / (TICKS / 2), 0, 1);
    const heart_rate_bpm = Math.round(jitter(lerp(CALM.heart_rate_bpm, HIGH.heart_rate_bpm, t), 3, rng));
    const respiratory_rate_bpm = Math.round(jitter(lerp(CALM.respiratory_rate_bpm, HIGH.respiratory_rate_bpm, t), 2, rng));
    const body_temperature_c = round(jitter(lerp(CALM.body_temperature_c, HIGH.body_temperature_c, t), 0.1, rng), 1);
    const motion_activity = round(clamp(jitter(lerp(CALM.motion_activity, HIGH.motion_activity, t), 0.05, rng), 0, 1), 3);
    const posture = motion_activity > 0.6 ? "moving" : t > 0.3 ? "standing" : "lying";
    const reading = {
      device_code: `FURFEEL-DEV-${dog.size_class.toUpperCase()}`,
      captured_at: new Date(Date.UTC(2026, 6, 20, 8, 0, 0) + (startTick + i) * 10_000).toISOString(),
      heart_rate_bpm, body_temperature_c, respiratory_rate_bpm, motion_activity, posture,
      ambient_temperature_c: round(jitter(26, 1.5, rng), 1),
      humidity_percent: round(jitter(60, 4, rng), 1),
      battery_percent: Math.max(20, 96 - (startTick + i)),
    };
    const { score, level, reasons } = scoreReading(reading, dog.baseline, recentScores.slice(-3));
    recentScores.push(score);
    rows.push({ dog, reading, score, level, reasons, valid: true });
  }
  return rows;
}

// Deliberate validation-range violations (docs/07 table) so this sheet also
// covers "what does the intake function do with bad data", not just the
// classifier. is_valid mirrors what telemetry-intake would flag; the field
// itself is left as the true received value (raw_payload is always kept
// verbatim, ADR-003) -- these rows show the INPUT, not the stored/flagged output.
function buildEdgeCaseRows(dog, rng) {
  const base = { device_code: `FURFEEL-DEV-${dog.size_class.toUpperCase()}`, posture: "standing", ambient_temperature_c: 24, humidity_percent: 55, battery_percent: 40 };
  return [
    {
      dog, valid: false, note: "heart_rate_bpm 310 > validation max 300 -> flagged is_valid=false, field stored null",
      reading: { ...base, captured_at: new Date(Date.UTC(2026, 6, 20, 9, 0, 0)).toISOString(),
        heart_rate_bpm: 310, respiratory_rate_bpm: 24, body_temperature_c: 38.6, motion_activity: 0.3 },
    },
    {
      dog, valid: false, note: "respiratory_rate_bpm missing (sensor dropout) -> stored null, classifier skips that rule only",
      reading: { ...base, captured_at: new Date(Date.UTC(2026, 6, 20, 9, 0, 10)).toISOString(),
        heart_rate_bpm: 95, respiratory_rate_bpm: null, body_temperature_c: 38.7, motion_activity: 0.3 },
    },
    {
      dog, valid: false, note: "captured_at 3h old, outside +/-1h skew -> flagged",
      reading: { ...base, captured_at: new Date(Date.UTC(2026, 6, 20, 5, 0, 0)).toISOString(),
        heart_rate_bpm: 92, respiratory_rate_bpm: 22, body_temperature_c: 38.6, motion_activity: 0.25 },
    },
    {
      dog, valid: true, note: "environmental_amplifier: ambient 34C AND humidity 85% -> heat-stress context +1",
      reading: { ...base, ambient_temperature_c: 34, humidity_percent: 85, captured_at: new Date(Date.UTC(2026, 6, 20, 14, 0, 0)).toISOString(),
        heart_rate_bpm: 100, respiratory_rate_bpm: 30, body_temperature_c: 38.9, motion_activity: 0.4 },
    },
    {
      dog, valid: true, note: "device_alerts.low_battery_percent (15) breached -- device health only, never a classifier input",
      reading: { ...base, battery_percent: 12, captured_at: new Date(Date.UTC(2026, 6, 20, 15, 0, 0)).toISOString(),
        heart_rate_bpm: 91, respiratory_rate_bpm: 23, body_temperature_c: 38.6, motion_activity: 0.28 },
    },
  ].map((r) => {
    if (r.reading.heart_rate_bpm === 310) {
      // Mirror telemetry-intake: out-of-range field nulled before scoring.
      const scored = scoreReading({ ...r.reading, heart_rate_bpm: null }, dog.baseline, []);
      return { ...r, ...scored };
    }
    const scored = scoreReading(r.reading, dog.baseline, []);
    return { ...r, ...scored };
  });
}

const HEADER = [
  "dog_name", "breed", "size_class", // context only -- not part of the device payload
  "device_code", "captured_at", "heart_rate_bpm", "body_temperature_c", "respiratory_rate_bpm",
  "motion_activity", "posture", "ambient_temperature_c", "humidity_percent", "battery_percent", // <- exact docs/07 payload fields
  "is_valid", "expected_score", "expected_level", "fired_rules", "note", // reference/annotation only
];

function csvCell(value) {
  if (value === null || value === undefined) return "";
  const s = String(value);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

const lines = [HEADER.join(",")];
let tick = 0;
for (const dog of DOGS) {
  const rng = mulberry32(dog.name.length * 97 + dog.weight_kg);
  for (const row of buildSweepRows(dog, rng, tick)) {
    lines.push(HEADER.map((h) => csvCell({
      dog_name: dog.name, breed: dog.breed, size_class: dog.size_class,
      device_code: row.reading.device_code, captured_at: row.reading.captured_at,
      heart_rate_bpm: row.reading.heart_rate_bpm, body_temperature_c: row.reading.body_temperature_c,
      respiratory_rate_bpm: row.reading.respiratory_rate_bpm, motion_activity: row.reading.motion_activity,
      posture: row.reading.posture, ambient_temperature_c: row.reading.ambient_temperature_c,
      humidity_percent: row.reading.humidity_percent, battery_percent: row.reading.battery_percent,
      is_valid: true, expected_score: row.score, expected_level: row.level,
      fired_rules: row.reasons.join(" | ") || "(none)", note: "",
    }[h])).join(","));
  }
  tick += 13;
  for (const row of buildEdgeCaseRows(dog, rng)) {
    lines.push(HEADER.map((h) => csvCell({
      dog_name: dog.name, breed: dog.breed, size_class: dog.size_class,
      device_code: row.reading.device_code, captured_at: row.reading.captured_at,
      heart_rate_bpm: row.reading.heart_rate_bpm, body_temperature_c: row.reading.body_temperature_c,
      respiratory_rate_bpm: row.reading.respiratory_rate_bpm, motion_activity: row.reading.motion_activity,
      posture: row.reading.posture, ambient_temperature_c: row.reading.ambient_temperature_c,
      humidity_percent: row.reading.humidity_percent, battery_percent: row.reading.battery_percent,
      is_valid: row.valid, expected_score: row.score, expected_level: row.level,
      fired_rules: row.reasons.join(" | ") || "(none)", note: row.note,
    }[h])).join(","));
  }
}

writeFileSync(outPath, lines.join("\n") + "\n", "utf8");
console.log(`Wrote ${lines.length - 1} rows to ${outPath}`);
