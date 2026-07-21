import { useCallback, useEffect, useState } from "react";
import type { FormEvent } from "react";
import { supabase } from "../lib/supabaseClient.ts";
import { fetchDogBaselines, saveDogThresholds } from "../lib/queries.ts";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card.tsx";
import { Button } from "./ui/button.tsx";
import { Input, Label } from "./ui/input.tsx";
import { useToast } from "./ui/toast.tsx";
// Single source of truth for every threshold (CLAUDE.md: "don't invent
// thresholds silently") — the same file the classifier itself reads.
import classifierConfig from "../../../../packages/shared/classifier_config.json";

const GLOBAL = classifierConfig.level_thresholds;

interface Field {
  key: "threshold_mild_min" | "threshold_moderate_min" | "threshold_high_min";
  label: string;
  globalDefault: number;
  help: string;
}

const FIELDS: Field[] = [
  {
    key: "threshold_mild_min",
    label: "Mild starts at score",
    globalDefault: GLOBAL.mild.min,
    help: "Below this, readings stay calm.",
  },
  {
    key: "threshold_moderate_min",
    label: "Moderate starts at score",
    globalDefault: GLOBAL.moderate.min,
    help: "Where the moderate alert kicks in.",
  },
  {
    key: "threshold_high_min",
    label: "High starts at score",
    globalDefault: GLOBAL.high.min,
    help: "Where the high (urgent) alert kicks in.",
  },
];

/** Draft form state: "" means "use the global default" (saves as null). */
type Draft = Record<Field["key"], string>;

function draftFromBaselines(baselines: { [K in Field["key"]]: number | null } | null): Draft {
  return {
    threshold_mild_min: baselines?.threshold_mild_min?.toString() ?? "",
    threshold_moderate_min: baselines?.threshold_moderate_min?.toString() ?? "",
    threshold_high_min: baselines?.threshold_high_min?.toString() ?? "",
  };
}

/**
 * Per-dog classifier threshold override (step 2, docs/08 AI Classification
 * Pipeline): dogs vary by size class, so a vet can move the score->level cut
 * points for one dog without touching the global defaults everyone else
 * uses. Blank = "use the global default" (stored as NULL in dog_baselines).
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

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const parsed: Record<Field["key"], number | null> = {
      threshold_mild_min: null,
      threshold_moderate_min: null,
      threshold_high_min: null,
    };
    for (const field of FIELDS) {
      const raw = draft[field.key].trim();
      if (raw === "") continue;
      const n = Number(raw);
      if (!Number.isInteger(n)) {
        setError(`${field.label} must be a whole number.`);
        return;
      }
      parsed[field.key] = n;
    }
    const mild = parsed.threshold_mild_min ?? GLOBAL.mild.min;
    const moderate = parsed.threshold_moderate_min ?? GLOBAL.moderate.min;
    const high = parsed.threshold_high_min ?? GLOBAL.high.min;
    if (!(mild < moderate && moderate < high)) {
      setError("Mild < moderate < high — each level must start at a higher score than the last.");
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const saved = await saveDogThresholds(supabase, dogId, parsed);
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

  function resetField(key: Field["key"]) {
    setDraft((prev) => ({ ...prev, [key]: "" }));
  }

  const dirty = FIELDS.some((f) => draft[f.key] !== savedDraft[f.key]);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Stress thresholds</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="m-0 mb-4 text-sm text-ink-muted">
          Score cut points that decide this dog&apos;s stress level (docs/08 AI Classification
          Pipeline). Leave a field blank to use the clinic-wide default.
        </p>
        {loading ? (
          <p className="m-0 text-sm text-ink-muted">Loading…</p>
        ) : (
          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            {FIELDS.map((field) => {
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
                      inputMode="numeric"
                      placeholder={`Default: ${field.globalDefault}`}
                      value={draft[field.key]}
                      onChange={(e) =>
                        setDraft((prev) => ({ ...prev, [field.key]: e.target.value }))
                      }
                      className="max-w-40"
                    />
                    {isCustom && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => resetField(field.key)}
                      >
                        Reset to default
                      </Button>
                    )}
                  </div>
                  <p className="m-0 text-xs text-ink-muted">{field.help}</p>
                </div>
              );
            })}
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
