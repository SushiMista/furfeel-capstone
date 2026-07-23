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
    title: "Body temperature",
    unit: "°C",
    fields: [
      {
        key: "body_temp_elevated_c",
        label: "Elevated at",
        globalDefault: SCORING.body_temperature.tiers[0].min,
        help: "Absolute temperature, not relative to baseline.",
        step: "0.1",
      },
      {
        key: "body_temp_high_c",
        label: "High at",
        globalDefault: SCORING.body_temperature.tiers[1].min,
        help: "",
        step: "0.1",
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
 *    respiratory rate, body temperature, motion, ambient heat, humidity)
 *    starts contributing points in the first place.
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
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Which category is showing -- draft state stays flat across all of them,
  // so switching tabs never loses an edit made in another one.
  const [category, setCategory] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const baselines = await fetchDogBaselines(supabase, dogId);
      const loaded = draftFromBaselines(baselines);
      setDraft(loaded);
      setSavedDraft(loaded);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load thresholds");
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
    // Same ordering check, one level finer, for every multi-tier variable.
    const orderedPairs: [Key, Key, string][] = [
      ["hr_ratio_elevated_min", "hr_ratio_moderate_min", "Heart rate: elevated < moderate"],
      ["hr_ratio_moderate_min", "hr_ratio_high_min", "Heart rate: moderate < high"],
      ["rr_ratio_elevated_min", "rr_ratio_high_min", "Respiratory rate: elevated < high"],
      ["body_temp_elevated_c", "body_temp_high_c", "Body temperature: elevated < high"],
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
      toast("success", "Thresholds saved");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save thresholds");
    } finally {
      setSaving(false);
    }
  }

  function resetField(key: Key) {
    setDraft((prev) => ({ ...prev, [key]: "" }));
  }

  const dirty = ALL_FIELDS.some((f) => draft[f.key] !== savedDraft[f.key]);

  function renderField(field: Field) {
    const { value, isCustom } = effectiveValue(field);
    return (
      <div key={field.key} className="flex flex-col gap-1.5">
        <div className="flex items-center justify-between gap-2">
          <Label htmlFor={field.key}>{field.label}</Label>
          <span
            className={
              isCustom
                ? "rounded-pill bg-brand-soft px-2 py-0.5 text-xs font-bold text-brand-strong"
                : "rounded-pill bg-surface-alt px-2 py-0.5 text-xs font-semibold text-ink-muted"
            }
          >
            {isCustom ? `Custom · effective ${value}` : `Default · ${value}`}
          </span>
        </div>
        <div className="flex items-center gap-2">
          <Input
            id={field.key}
            type="number"
            inputMode="decimal"
            step={field.step ?? "1"}
            placeholder={`Default: ${field.globalDefault}`}
            value={draft[field.key]}
            onChange={(e) => setDraft((prev) => ({ ...prev, [field.key]: e.target.value }))}
            className="max-w-40"
          />
          {isCustom && (
            <Button type="button" variant="ghost" size="sm" onClick={() => resetField(field.key)}>
              Reset to default
            </Button>
          )}
        </div>
        {field.help && <p className="m-0 text-xs text-ink-muted">{field.help}</p>}
      </div>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Stress thresholds</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="m-0 mb-4 text-sm text-ink-muted">
          Every number here is clinic-wide by default (docs/08 AI Classification Pipeline).
          Leave a field blank to keep using it for this dog; fill one in to override it — dogs
          vary by size, so a small dog's normal heart rate can be a large dog's elevated one.
        </p>
        {loading ? (
          <p className="m-0 text-sm text-ink-muted">Loading…</p>
        ) : (
          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            {/* Categorized tabs (not one long stacked scroll): same tab-bar
             * style as the dog-detail page's own section tabs. */}
            <div role="tablist" aria-label="Threshold categories" className="flex flex-wrap gap-2">
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
                      "inline-flex items-center gap-2 rounded-md px-4 py-2 text-sm font-semibold transition-colors duration-fast",
                      category === i
                        ? "bg-brand-soft text-brand-strong"
                        : "text-ink-muted hover:bg-surface-alt hover:text-ink",
                    )}
                  >
                    {cat.title}
                    {/* Decorative only -- aria-hidden, not aria-label, so it
                     * never gets concatenated into this button's own
                     * accessible name (that broke exact-name tab lookups in
                     * tests the moment a tab went dirty). The Save button's
                     * enabled state and each field's "Custom" badge already
                     * carry the same information for assistive tech. */}
                    {catDirty && (
                      <span className="h-1.5 w-1.5 rounded-full bg-brand" aria-hidden="true" />
                    )}
                  </button>
                );
              })}
            </div>

            <section className="flex flex-col gap-4">
              {CATEGORIES[category].unit !== "points" && (
                <h3 className="m-0 text-sm font-semibold text-ink">
                  {CATEGORIES[category].title}
                  <span className="ml-2 font-normal text-ink-muted">
                    ({CATEGORIES[category].unit})
                  </span>
                </h3>
              )}
              {CATEGORIES[category].fields.map(renderField)}
            </section>

            {error && (
              <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
                {error}
              </p>
            )}
            <div>
              <Button type="submit" disabled={saving || !dirty}>
                {saving ? "Saving…" : "Save thresholds"}
              </Button>
            </div>
          </form>
        )}
      </CardContent>
    </Card>
  );
}
