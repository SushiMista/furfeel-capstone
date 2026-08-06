import { friendlyError } from "../lib/errors.ts";
import { useCallback, useEffect, useState } from "react";
import type { FormEvent } from "react";
import { supabase } from "../lib/supabaseClient.ts";
import { fetchDogBaselines, saveDogThresholds } from "../lib/queries.ts";
import type { DogThresholdOverrides } from "../lib/queries.ts";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card.tsx";
import { Button } from "./ui/button.tsx";
import { Input, Label } from "./ui/input.tsx";
import { useToast } from "./ui/toast.tsx";
import { cn } from "../lib/cn.ts";
// Single source of truth for every threshold (CLAUDE.md: "don't invent
// thresholds silently") — the same file the classifier itself reads.
import classifierConfig from "../../../../packages/shared/classifier_config.json";

type Key = keyof DogThresholdOverrides;

interface Field {
  key: Key;
  label: string;
  globalDefault: number;
  help: string;
  /** Whole-number input (score cutoffs) vs. decimal (ratios/°C/%). */
  step?: string;
}

const SCORE_RULES = classifierConfig.level_thresholds;
const SCORING = classifierConfig.scoring_rules;
const ENV = SCORING.environmental_amplifier;

/** Score-level cutoffs: how many total points reach mild/moderate/high. */
const SCORE_FIELDS: Field[] = [
  {
    key: "threshold_mild_min",
    label: "Mild starts at score",
    globalDefault: SCORE_RULES.mild.min,
    help: "Below this, readings stay calm.",
  },
  {
    key: "threshold_moderate_min",
    label: "Moderate starts at score",
    globalDefault: SCORE_RULES.moderate.min,
    help: "Where the moderate alert kicks in.",
  },
  {
    key: "threshold_high_min",
    label: "High starts at score",
    globalDefault: SCORE_RULES.high.min,
    help: "Where the high (urgent) alert kicks in.",
  },
];

/** One category per raw signal: when THIS variable starts contributing
 * points, independent of the score cutoffs above. Grouped exactly the way a
 * vet asked for — "let me set the threshold for each variable itself." Shown
 * one at a time behind a tab bar (not stacked) so the editor never turns
 * into one long scroll. */
interface VariableGroup {
  title: string;
  unit: string;
  fields: Field[];
}

const VARIABLE_GROUPS: VariableGroup[] = [
  {
    title: "Heart rate",
    unit: "× resting baseline",
    fields: [
      {
        key: "hr_ratio_elevated_min",
        label: "Elevated at",
        globalDefault: SCORING.heart_rate_elevated.tiers[0].min,
        help: "Ratio to this dog's resting heart rate (docs/08: hr_ratio).",
        step: "0.01",
      },
      {
        key: "hr_ratio_moderate_min",
        label: "Moderate at",
        globalDefault: SCORING.heart_rate_elevated.tiers[1].min,
        help: "",
        step: "0.01",
      },
      {
        key: "hr_ratio_high_min",
        label: "High at",
        globalDefault: SCORING.heart_rate_elevated.tiers[2].min,
        help: "",
        step: "0.01",
      },
    ],
  },
  {
    title: "Respiratory rate",
    unit: "× resting baseline",
    fields: [
      {
        key: "rr_ratio_elevated_min",
        label: "Elevated at",
        globalDefault: SCORING.respiratory_elevated.tiers[0].min,
        help: "Ratio to this dog's resting respiratory rate.",
        step: "0.01",
      },
      {
        key: "rr_ratio_high_min",
        label: "High (panting) at",
        globalDefault: SCORING.respiratory_elevated.tiers[1].min,
        help: "",
        step: "0.01",
      },
    ],
  },
  {
    title: "Motion activity",
    unit: "0–1 index",
    fields: [
      {
        key: "motion_elevated_min",
        label: "Restless at",
        globalDefault: SCORING.motion_restlessness.tiers[0].min,
        help: "Also the floor for the posture + high-motion rule.",
        step: "0.01",
      },
      {
        key: "motion_high_min",
        label: "Very restless at",
        globalDefault: SCORING.motion_restlessness.tiers[1].min,
        help: "",
        step: "0.01",
      },
    ],
  },
  {
    title: "Ambient temperature",
    unit: "°C",
    fields: [
      {
        key: "ambient_heat_c",
        label: "Heat-stress context above",
        globalDefault: ENV.ambient_temperature_c_above,
        help: "Combines with humidity below (either counts).",
        step: "0.1",
      },
    ],
  },
  {
    title: "Humidity",
    unit: "%",
    fields: [
      {
        key: "humidity_heat_pct",
        label: "Heat-stress context above",
        globalDefault: ENV.humidity_percent_above,
        help: "",
        step: "0.1",
      },
    ],
  },
];

/** Score cutoffs join the per-variable groups as just another category, so
 * the whole editor is one uniform tab bar instead of a special-cased first
 * section plus a list of groups. */
const CATEGORIES: VariableGroup[] = [
  { title: "Score cutoffs", unit: "points", fields: SCORE_FIELDS },
  ...VARIABLE_GROUPS,
];

const ALL_FIELDS: Field[] = CATEGORIES.flatMap((c) => c.fields);

/** Draft form state: "" means "use the global default" (saves as null). */
type Draft = Record<Key, string>;

function draftFromBaselines(baselines: Partial<Record<Key, number | null>> | null): Draft {
  const draft = {} as Draft;
  for (const field of ALL_FIELDS) {
    draft[field.key] = baselines?.[field.key]?.toString() ?? "";
  }
  return draft;
}

/**
 * Per-dog classifier threshold overrides (docs/08 AI Classification
 * Pipeline). Two independent, complementary controls a vet can tune per dog,
 * falling back to the clinic-wide default when left blank:
 *  - score cutoffs: how many total points reach mild/moderate/high.
 *  - per-variable thresholds: when each individual signal (heart rate,
 *    respiratory rate, motion, ambient heat, humidity) starts contributing
 *    points in the first place.
 *
 * Writes go through dog_baselines_insert/update RLS
 * (is_clinic_member(dog_id)) exactly like the resting-value baselines this
 * table already carries — this component adds no new authorization, and
 * every dog reachable here already passed the same clinic-membership check
 * on the way in (dogs_select_clinic_staff), so there's nothing extra to gate
 * client-side.
 */
export function ThresholdEditor({ dogId }: { dogId: string }) {
  const toast = useToast();
  const [draft, setDraft] = useState<Draft>(draftFromBaselines(null));
  const [savedDraft, setSavedDraft] = useState<Draft>(draftFromBaselines(null));
  const [baselinesData, setBaselinesData] = useState<{
    hr: number;
    rr: number;
  }>({
    hr: classifierConfig.global_baselines.heart_rate_bpm,
    rr: classifierConfig.global_baselines.respiratory_rate_bpm,
  });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [category, setCategory] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const baselines = await fetchDogBaselines(supabase, dogId);
      const loaded = draftFromBaselines(baselines);
      setDraft(loaded);
      setSavedDraft(loaded);
      setBaselinesData({
        hr: baselines?.resting_heart_rate_bpm ?? classifierConfig.global_baselines.heart_rate_bpm,
        rr: baselines?.resting_respiratory_rate_bpm ?? classifierConfig.global_baselines.respiratory_rate_bpm,
      });
      setError(null);
    } catch (err) {
      setError(friendlyError(err, "load thresholds"));
    } finally {
      setLoading(false);
    }
  }, [dogId]);

  useEffect(() => {
    load();
  }, [load]);

  function effectiveValue(field: Field): { value: number; isCustom: boolean } {
    const raw = draft[field.key];
    if (raw.trim() === "") return { value: field.globalDefault, isCustom: false };
    const parsed = Number(raw);
    return { value: Number.isFinite(parsed) ? parsed : field.globalDefault, isCustom: true };
  }

  function parseDraft(): { values: DogThresholdOverrides; error: string | null } {
    const values = {} as DogThresholdOverrides;
    for (const field of ALL_FIELDS) {
      const raw = draft[field.key].trim();
      if (raw === "") {
        values[field.key] = null;
        continue;
      }
      const n = Number(raw);
      if (!Number.isFinite(n)) {
        return { values, error: `${field.label} must be a number.` };
      }
      values[field.key] = n;
    }
    return { values, error: null };
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const { values, error: parseError } = parseDraft();
    if (parseError) {
      setError(parseError);
      return;
    }

    const mild = values.threshold_mild_min ?? SCORE_RULES.mild.min;
    const moderate = values.threshold_moderate_min ?? SCORE_RULES.moderate.min;
    const high = values.threshold_high_min ?? SCORE_RULES.high.min;
    if (!(mild < moderate && moderate < high)) {
      setError("Mild < moderate < high — each level must start at a higher score than the last.");
      return;
    }

    const orderedPairs: [Key, Key, string][] = [
      ["hr_ratio_elevated_min", "hr_ratio_moderate_min", "Heart rate: elevated < moderate"],
      ["hr_ratio_moderate_min", "hr_ratio_high_min", "Heart rate: moderate < high"],
      ["rr_ratio_elevated_min", "rr_ratio_high_min", "Respiratory rate: elevated < high"],
      ["motion_elevated_min", "motion_high_min", "Motion: restless < very restless"],
    ];
    const fieldByKey = Object.fromEntries(ALL_FIELDS.map((f) => [f.key, f]));
    for (const [lowKey, highKey, message] of orderedPairs) {
      const low = values[lowKey] ?? fieldByKey[lowKey].globalDefault;
      const high2 = values[highKey] ?? fieldByKey[highKey].globalDefault;
      if (!(low < high2)) {
        setError(`${message} — each tier must start above the last.`);
        return;
      }
    }

    setSaving(true);
    setError(null);
    try {
      const saved = await saveDogThresholds(supabase, dogId, values);
      const loaded = draftFromBaselines(saved);
      setDraft(loaded);
      setSavedDraft(loaded);
      setBaselinesData({
        hr: saved?.resting_heart_rate_bpm ?? classifierConfig.global_baselines.heart_rate_bpm,
        rr: saved?.resting_respiratory_rate_bpm ?? classifierConfig.global_baselines.respiratory_rate_bpm,
      });
      toast("success", "Thresholds saved");
    } catch (err) {
      setError(friendlyError(err, "save thresholds"));
    } finally {
      setSaving(false);
    }
  }

  function resetField(key: Key) {
    setDraft((prev) => ({ ...prev, [key]: "" }));
  }

  const dirty = ALL_FIELDS.some((f) => draft[f.key] !== savedDraft[f.key]);

  // Helper to render clinical physical conversion badge next to input
  function renderClinicalBadge(field: Field, value: number) {
    if (field.key.startsWith("hr_ratio_")) {
      const targetBpm = Math.round(value * baselinesData.hr);
      return (
        <span className="inline-flex items-center gap-1 rounded bg-brand-soft/60 px-2 py-0.5 text-xs font-semibold text-brand-strong">
          ⚡ Trigger: ~{targetBpm} bpm ({value}× of {baselinesData.hr} resting HR)
        </span>
      );
    }
    if (field.key.startsWith("rr_ratio_")) {
      const targetRr = Math.round(value * baselinesData.rr);
      return (
        <span className="inline-flex items-center gap-1 rounded bg-brand-soft/60 px-2 py-0.5 text-xs font-semibold text-brand-strong">
          ⚡ Trigger: ~{targetRr} breaths/min ({value}× of {baselinesData.rr} resting RR)
        </span>
      );
    }
    return null;
  }

  function renderField(field: Field) {
    const { value, isCustom } = effectiveValue(field);
    return (
      <div key={field.key} className="flex flex-col gap-2 rounded-lg border border-surface-alt bg-surface-base/50 p-3.5 transition-all">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <Label htmlFor={field.key} className="font-semibold text-ink">
            {field.label}
          </Label>
          <span
            className={
              isCustom
                ? "rounded-pill bg-brand-soft px-2.5 py-0.5 text-xs font-bold text-brand-strong shadow-xs"
                : "rounded-pill bg-surface-alt px-2.5 py-0.5 text-xs font-medium text-ink-muted"
            }
          >
            {isCustom ? `Custom · effective ${value}` : `Default · ${value}`}
          </span>
        </div>

        <div className="flex items-center gap-3">
          <Input
            id={field.key}
            type="number"
            inputMode="decimal"
            step={field.step ?? "1"}
            placeholder={`Default: ${field.globalDefault}`}
            value={draft[field.key]}
            onChange={(e) => setDraft((prev) => ({ ...prev, [field.key]: e.target.value }))}
            className="max-w-44 bg-surface-base font-medium"
          />
          {isCustom && (
            <Button type="button" variant="ghost" size="sm" onClick={() => resetField(field.key)} className="text-xs text-ink-muted hover:text-high-fg">
              Reset to default
            </Button>
          )}
        </div>

        {renderClinicalBadge(field, value)}

        {field.help && <p className="m-0 text-xs text-ink-muted leading-relaxed">{field.help}</p>}
      </div>
    );
  }

  // Current category cutoffs for visual spectrum display
  const currentCategoryObj = CATEGORIES[category];
  const mildVal = effectiveValue(SCORE_FIELDS[0]).value;
  const modVal = effectiveValue(SCORE_FIELDS[1]).value;
  const highVal = effectiveValue(SCORE_FIELDS[2]).value;

  return (
    <Card className="shadow-xs border-surface-alt">
      <CardHeader className="pb-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <CardTitle className="text-lg font-bold">Stress thresholds</CardTitle>
            <p className="m-0 mt-1 text-sm text-ink-muted">
              Customize alert triggers per dog. Numbers default to clinic-wide standards. Fill in a field to override for this patient.
            </p>
          </div>

          {/* Resting Baseline Summary Pills */}
          <div className="flex flex-wrap items-center gap-2 text-xs">
            <div className="flex items-center gap-1.5 rounded-md bg-surface-alt/70 px-2.5 py-1 font-medium text-ink">
              <span className="text-brand font-bold">HR Baseline:</span> {baselinesData.hr} bpm
            </div>
            <div className="flex items-center gap-1.5 rounded-md bg-surface-alt/70 px-2.5 py-1 font-medium text-ink">
              <span className="text-brand font-bold">RR Baseline:</span> {baselinesData.rr} bpm
            </div>
          </div>
        </div>
      </CardHeader>

      <CardContent>
        {loading ? (
          <div className="py-6 text-center text-sm text-ink-muted">Loading thresholds & baselines…</div>
        ) : (
          <form onSubmit={handleSubmit} className="flex flex-col gap-5">
            {/* Categorized Tab Bar */}
            <div role="tablist" aria-label="Threshold categories" className="flex flex-wrap gap-1.5 border-b border-surface-alt pb-3">
              {CATEGORIES.map((cat, i) => {
                const catDirty = cat.fields.some((f) => draft[f.key] !== savedDraft[f.key]);
                return (
                  <button
                    key={cat.title}
                    type="button"
                    role="tab"
                    aria-selected={category === i}
                    onClick={() => setCategory(i)}
                    className={cn(
                      "inline-flex items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-semibold transition-all duration-fast",
                      category === i
                        ? "bg-brand-soft text-brand-strong shadow-xs"
                        : "text-ink-muted hover:bg-surface-alt hover:text-ink",
                    )}
                  >
                    {cat.title}
                    {catDirty && (
                      <span className="h-2 w-2 rounded-full bg-brand shadow-xs" aria-hidden="true" />
                    )}
                  </button>
                );
              })}
            </div>

            {/* Visual Stress Level Spectrum Bar (for Score Cutoffs) */}
            {currentCategoryObj.title === "Score cutoffs" && (
              <div className="flex flex-col gap-2 rounded-lg border border-surface-alt bg-surface-alt/20 p-4">
                <div className="flex items-center justify-between text-xs font-semibold text-ink">
                  <span>Visual Stress Score Cutoffs Spectrum</span>
                  <span className="text-ink-muted">Cumulative Classifier Points</span>
                </div>
                {/* Spectrum Bar */}
                <div className="relative h-5 w-full overflow-hidden rounded-full bg-surface-alt flex">
                  <div className="flex items-center justify-center bg-emerald-500/20 text-[10px] font-bold text-emerald-700 transition-all" style={{ width: `${Math.min(100, (mildVal / 10) * 100)}%` }}>
                    Calm (0-{mildVal - 1})
                  </div>
                  <div className="flex items-center justify-center bg-amber-500/30 text-[10px] font-bold text-amber-800 transition-all" style={{ width: `${Math.min(100, ((modVal - mildVal) / 10) * 100)}%` }}>
                    Mild ({mildVal}-{modVal - 1})
                  </div>
                  <div className="flex items-center justify-center bg-orange-500/30 text-[10px] font-bold text-orange-800 transition-all" style={{ width: `${Math.min(100, ((highVal - modVal) / 10) * 100)}%` }}>
                    Moderate ({modVal}-{highVal - 1})
                  </div>
                  <div className="flex-1 flex items-center justify-center bg-rose-500/30 text-[10px] font-bold text-rose-800 transition-all">
                    High ({highVal}+)
                  </div>
                </div>
              </div>
            )}

            {/* Active Category Fields */}
            <section className="flex flex-col gap-3">
              {currentCategoryObj.unit !== "points" && (
                <div className="flex items-center justify-between pb-1 border-b border-surface-alt/50">
                  <h3 className="m-0 text-sm font-bold text-ink">
                    {currentCategoryObj.title}
                  </h3>
                  <span className="text-xs font-medium text-ink-muted bg-surface-alt px-2 py-0.5 rounded">
                    Unit: {currentCategoryObj.unit}
                  </span>
                </div>
              )}
              {currentCategoryObj.fields.map(renderField)}
            </section>

            {error && (
              <p role="alert" className="rounded-md bg-high-soft px-3.5 py-2.5 text-sm font-medium text-high-fg border border-high-fg/20">
                {error}
              </p>
            )}

            <div className="flex items-center justify-between pt-2">
              <Button type="submit" disabled={saving || !dirty} className="font-semibold shadow-xs">
                {saving ? "Saving…" : "Save thresholds"}
              </Button>
              {dirty && (
                <span className="text-xs font-medium text-amber-700 bg-amber-50 px-2.5 py-1 rounded">
                  ⚠️ You have unsaved changes
                </span>
              )}
            </div>
          </form>
        )}
      </CardContent>
    </Card>
  );
}
