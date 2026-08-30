import { useState } from "react";
import {
  Activity,
  Clock,
  Footprints,
  Pill,
  Plus,
  Stethoscope,
  Syringe,
  Utensils,
} from "lucide-react";
import { friendlyError } from "../lib/errors.ts";
import { supabase } from "../lib/supabaseClient.ts";
import { recordClinicalIntervention } from "../lib/queries.ts";
import { useAuth } from "../lib/useAuth.ts";
import { useToast } from "./ui/toast.tsx";
import { Button } from "./ui/button.tsx";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "./ui/card.tsx";
import { Input, Select } from "./ui/input.tsx";
import { EmptyState } from "./ui/empty-state.tsx";
import { cn } from "../lib/cn.ts";
import type {
  ClinicalIntervention,
  ClinicalInterventionType,
} from "../../../../packages/shared/types/index.ts";

interface Props {
  dogId: string;
  clinicId?: string | null;
  interventions: ClinicalIntervention[];
  onRecorded?: () => void;
}

const TYPE_CONFIG: Record<
  ClinicalInterventionType,
  { label: string; icon: typeof Pill; color: string; bg: string }
> = {
  medication: {
    label: "Medication",
    icon: Pill,
    color: "text-purple-600",
    bg: "bg-purple-50 border-purple-200",
  },
  procedure: {
    label: "Procedure / Surgery",
    icon: Syringe,
    color: "text-rose-600",
    bg: "bg-rose-50 border-rose-200",
  },
  vet_exam: {
    label: "Vet Exam",
    icon: Stethoscope,
    color: "text-blue-600",
    bg: "bg-blue-50 border-blue-200",
  },
  feeding: {
    label: "Feeding / Nutrition",
    icon: Utensils,
    color: "text-amber-600",
    bg: "bg-amber-50 border-amber-200",
  },
  walk: {
    label: "Walk / Relief",
    icon: Footprints,
    color: "text-emerald-600",
    bg: "bg-emerald-50 border-emerald-200",
  },
  other: {
    label: "Other Event",
    icon: Activity,
    color: "text-slate-600",
    bg: "bg-slate-50 border-slate-200",
  },
};

export function ClinicalInterventionsList({
  dogId,
  clinicId,
  interventions,
  onRecorded,
}: Props) {
  const { session } = useAuth();
  const toast = useToast();
  const [isAdding, setIsAdding] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Form State
  const [type, setType] = useState<ClinicalInterventionType>("medication");
  const [title, setTitle] = useState("");
  const [dosage, setDosage] = useState("");
  const [notes, setNotes] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    setSaving(true);
    setError(null);
    try {
      await recordClinicalIntervention(supabase, {
        dog_id: dogId,
        clinic_id: clinicId ?? null,
        intervention_type: type,
        title: title.trim(),
        dosage: dosage.trim() || null,
        notes: notes.trim() || null,
        administered_by: session?.user?.id ?? null,
      });

      toast("success", "Treatment event recorded successfully");
      setTitle("");
      setDosage("");
      setNotes("");
      setIsAdding(false);
      onRecorded?.();
    } catch (err) {
      setError(friendlyError(err, "record clinical event"));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="flex flex-col gap-6">
      {/* Action Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-hairline pb-4">
        <div>
          <h2 className="m-0 text-lg font-bold text-ink tracking-tight">Clinical Treatments &amp; Events</h2>
          <p className="m-0 mt-0.5 text-xs text-ink-muted">
            Log medications, feedings, and clinical procedures to cross-correlate with telemetry recovery
          </p>
        </div>
        <Button
          onClick={() => setIsAdding(!isAdding)}
          size="sm"
          className="font-semibold shadow-xs"
        >
          <Plus size={14} className="mr-1.5" />
          {isAdding ? "Cancel" : "Log Treatment"}
        </Button>
      </div>

      {/* Add Form Accordion / Card */}
      {isAdding && (
        <Card className="border-brand/30 bg-brand-soft/20 shadow-xs animate-in fade-in-50 duration-200">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-bold text-ink">New Clinical Event</CardTitle>
            <CardDescription className="text-xs">
              Record an administered drug, meal, walk, or observation
            </CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              {error && (
                <p className="rounded-md bg-high-soft px-3 py-2 text-xs font-semibold text-high-fg">
                  {error}
                </p>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="flex flex-col gap-1">
                  <label className="text-xs font-semibold text-ink">Event Type</label>
                  <Select
                    value={type}
                    onChange={(e) => setType(e.target.value as ClinicalInterventionType)}
                    className="h-9 text-xs bg-surface"
                  >
                    <option value="medication">💊 Medication</option>
                    <option value="procedure">💉 Procedure / Surgery</option>
                    <option value="vet_exam">🩺 Vet Exam</option>
                    <option value="feeding">🍲 Feeding / Nutrition</option>
                    <option value="walk">🐾 Walk / Relief</option>
                    <option value="other">📝 Other</option>
                  </Select>
                </div>

                <div className="flex flex-col gap-1 sm:col-span-2">
                  <label className="text-xs font-semibold text-ink">
                    {type === "medication"
                      ? "Drug Name & Route"
                      : type === "feeding"
                        ? "Diet / Food Type"
                        : "Title / Summary"}
                  </label>
                  <Input
                    required
                    placeholder={
                      type === "medication"
                        ? "e.g. Gabapentin, Acepromazine, Trazodone"
                        : type === "feeding"
                          ? "e.g. GI Recovery Wet Food, Kibble"
                          : "e.g. Bandage Change, Physical Checkup"
                    }
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="h-9 text-xs bg-surface"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="flex flex-col gap-1">
                  <label className="text-xs font-semibold text-ink">Dosage / Quantity</label>
                  <Input
                    placeholder="e.g. 100mg PO, 1 cup, 15 min"
                    value={dosage}
                    onChange={(e) => setDosage(e.target.value)}
                    className="h-9 text-xs bg-surface"
                  />
                </div>

                <div className="flex flex-col gap-1 sm:col-span-2">
                  <label className="text-xs font-semibold text-ink">Clinical Notes &amp; Observations</label>
                  <Input
                    placeholder="e.g. Patient took well with treat, resting calmly"
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    className="h-9 text-xs bg-surface"
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2 border-t border-hairline">
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => setIsAdding(false)}
                  disabled={saving}
                >
                  Cancel
                </Button>
                <Button type="submit" size="sm" disabled={saving || !title.trim()}>
                  {saving ? "Saving…" : "Save Event"}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {/* Timeline List */}
      {interventions.length === 0 ? (
        <EmptyState>
          No clinical treatments or events logged yet. Click &quot;Log Treatment&quot; to record medications, feedings, or veterinary procedures.
        </EmptyState>
      ) : (
        <div className="relative pl-6 space-y-4 before:absolute before:left-2.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-hairline">
          {interventions.map((item) => {
            const config = TYPE_CONFIG[item.intervention_type] ?? TYPE_CONFIG.other;
            const Icon = config.icon;
            const date = new Date(item.created_at);

            return (
              <div
                key={item.id}
                className="relative flex flex-col gap-1.5 rounded-xl border border-hairline bg-surface p-4 shadow-2xs transition-shadow hover:shadow-xs"
              >
                {/* Timeline Node Dot */}
                <div
                  className={cn(
                    "absolute -left-[23px] top-4 flex h-5 w-5 items-center justify-center rounded-full border bg-surface",
                    config.bg,
                  )}
                >
                  <Icon size={11} className={config.color} />
                </div>

                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span
                      className={cn(
                        "inline-flex items-center gap-1 rounded-md px-2 py-0.5 text-[11px] font-bold border",
                        config.bg,
                        config.color,
                      )}
                    >
                      <Icon size={11} />
                      {config.label}
                    </span>
                    <h3 className="m-0 text-sm font-bold text-ink">{item.title}</h3>
                    {item.dosage && (
                      <span className="rounded-md bg-surface-alt px-2 py-0.5 text-xs font-semibold text-ink-muted">
                        {item.dosage}
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-1 text-[11px] font-medium text-ink-muted">
                    <Clock size={12} />
                    <span>{date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</span>
                    <span className="text-ink-muted/50">•</span>
                    <span>{date.toLocaleDateString()}</span>
                  </div>
                </div>

                {item.notes && (
                  <p className="m-0 text-xs text-ink-muted leading-relaxed pl-1">
                    {item.notes}
                  </p>
                )}

                {item.administered_by_name && (
                  <p className="m-0 text-[10px] font-medium text-ink-muted/70 pt-1 border-t border-hairline/50">
                    Administered by: <strong className="text-ink-muted">{item.administered_by_name}</strong>
                  </p>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
