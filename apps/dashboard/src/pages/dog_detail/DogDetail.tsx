import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useState } from "react";
import { Link, useParams, useSearchParams } from "react-router-dom";
import {
  Activity,
  ArrowLeft,
  BarChart3,
  BellRing,
  Check,
  Edit3,
  FileText,
  HeartPulse,
  MapPin,
  Pill,
  SlidersHorizontal,
  Stethoscope,
  Thermometer,
  Wind,
  type LucideIcon,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  acknowledgeAlert,
  fetchClassificationHistory,
  fetchClinicalInterventions,
  fetchDailyStressSummary,
  fetchDog,
  fetchRecentAlerts,
  fetchTelemetryHistory,
  fetchStressLabels,
  fetchMediaSubmissions,
  updateDogWardAndAdmission,
  type DailyStressSummaryRow,
  type StressLabelWithVet,
} from "../../lib/queries.ts";
import { ConfirmOverridePanel, MediaItem } from "../vet_review/VetReview.tsx";
import { useAuth } from "../../lib/useAuth.ts";
import { TelemetryChart } from "../../components/TelemetryChart.tsx";
import { StressMixChart } from "../../components/StressMixChart.tsx";
import { StressTimeline } from "../../components/StressTimeline.tsx";
import { StressLevelBadge } from "../../components/StressLevelBadge.tsx";
import { MicroSparkline } from "../../components/MicroSparkline.tsx";
import { AlertCard } from "../../components/AlertCard.tsx";
import { VetNotes } from "../../components/VetNotes.tsx";
import { ClinicalInterventionsList } from "../../components/ClinicalInterventionsList.tsx";
import { ThresholdEditor } from "../../components/ThresholdEditor.tsx";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Input, Select } from "../../components/ui/input.tsx";
import { Button } from "../../components/ui/button.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { useToast } from "../../components/ui/toast.tsx";
import { cn } from "../../lib/cn.ts";
import type {
  Alert,
  ClinicalIntervention,
  Dog,
  StressClassification,
  TelemetryReading,
  MediaSubmission,
} from "../../../../../packages/shared/types/index.ts";

import { formatPosture } from "../../lib/posture.ts";

const HISTORY_LIMIT = 50;

/** Section tabs (docs/05): redesigned with icons & matching Board Controls style. */
const TABS = [
  { id: "alerts", label: "Alerts", icon: BellRing },
  { id: "telemetry", label: "Live telemetry", icon: Activity },
  { id: "interventions", label: "Treatments & Meds", icon: Pill },
  { id: "stress", label: "Stress history", icon: BarChart3 },
  { id: "notes", label: "Vet notes", icon: FileText },
  { id: "thresholds", label: "Thresholds", icon: SlidersHorizontal },
  { id: "review", label: "Vet review", icon: Stethoscope },
] as const;
type TabId = (typeof TABS)[number]["id"];

/** Vital card (docs/19 §7, docs/21 Phase 2): icon + label header, big tabular
 * value, small unit, and a recent-trend micro-sparkline. */
function Vital({
  label,
  icon: Icon,
  value,
  unit,
  series,
}: {
  label: string;
  icon: LucideIcon;
  value: number | string | null | undefined;
  unit?: string;
  series?: number[];
}) {
  return (
    <div className="flex min-w-28 flex-1 flex-col gap-1.5 rounded-md bg-surface-alt px-4 py-3">
      <div className="flex items-center gap-1.5 text-xs font-medium text-ink-muted">
        <Icon size={14} aria-hidden="true" className="text-brand" />
        {label}
      </div>
      <div className="text-xl sm:text-2xl lg:text-3xl font-bold leading-tight tabular-nums text-ink truncate">
        {value ?? "—"}
        {unit && <span className="ml-1 text-xs font-normal text-ink-muted">{unit}</span>}
      </div>
      {series && <MicroSparkline series={series} track className="mt-0.5" />}
    </div>
  );
}

/** Last N non-null values of a vital, oldest → newest, for the sparkline. */
function seriesOf(
  readings: TelemetryReading[],
  pick: (r: TelemetryReading) => number | null | undefined,
  limit = 12,
): number[] {
  return readings
    .map(pick)
    .filter((v): v is number => typeof v === "number" && Number.isFinite(v))
    .slice(-limit);
}

export function DogDetail() {
  const { dogId } = useParams<{ dogId: string }>();
  const { session } = useAuth();
  const toast = useToast();
  const [searchParams, setSearchParams] = useSearchParams();
  const [dog, setDog] = useState<Dog | null>(null);
  const [readings, setReadings] = useState<TelemetryReading[]>([]);
  const [classifications, setClassifications] = useState<StressClassification[]>([]);
  const [alerts, setAlerts] = useState<Alert[]>([]);
  const [mixSummary, setMixSummary] = useState<DailyStressSummaryRow[]>([]);
  const [stressMixDays, setStressMixDays] = useState<number>(14);
  const [labels, setLabels] = useState<StressLabelWithVet[]>([]);
  const [media, setMedia] = useState<MediaSubmission[]>([]);
  const [interventions, setInterventions] = useState<ClinicalIntervention[]>([]);
  const [editingWard, setEditingWard] = useState(false);
  const [wardDraft, setWardDraft] = useState("");
  const [admissionDraft, setAdmissionDraft] = useState<string>("outpatient");
  const [savingWard, setSavingWard] = useState(false);
  const [tab, setTabState] = useState<TabId>(() => {
    const defaultTab = searchParams.get("tab") as TabId;
    return TABS.some((t) => t.id === defaultTab) ? defaultTab : "alerts";
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const setTab = (newTab: TabId) => {
    setTabState(newTab);
    setSearchParams((prev) => {
      prev.set("tab", newTab);
      return prev;
    });
  };

  const load = useCallback(async () => {
    if (!dogId) return;
    try {
      const [dogRow, history, classHistory, recentAlerts, mixRows, labelRows, mediaRows, interventionRows] = await Promise.all([
        fetchDog(supabase, dogId),
        fetchTelemetryHistory(supabase, dogId, HISTORY_LIMIT),
        fetchClassificationHistory(supabase, dogId, HISTORY_LIMIT),
        fetchRecentAlerts(supabase, dogId),
        fetchDailyStressSummary(supabase, dogId, stressMixDays),
        fetchStressLabels(supabase, dogId),
        fetchMediaSubmissions(supabase, dogId),
        fetchClinicalInterventions(supabase, dogId),
      ]);
      setDog(dogRow);
      if (dogRow) {
        setWardDraft(dogRow.ward_location ?? "");
        setAdmissionDraft(dogRow.admission_status ?? "outpatient");
      }
      setReadings(history);
      setClassifications(classHistory);
      setAlerts(recentAlerts);
      setMixSummary(mixRows);
      setLabels(labelRows);
      setMedia(mediaRows);
      setInterventions(interventionRows);
      setError(null);
    } catch (err) {
      setError(friendlyError(err, "load this dog"));
    } finally {
      setLoading(false);
    }
  }, [dogId, stressMixDays]);

  useEffect(() => {
    load();
  }, [load]);

  const handleSaveWard = async () => {
    if (!dogId) return;
    setSavingWard(true);
    try {
      await updateDogWardAndAdmission(supabase, dogId, wardDraft.trim() || null, admissionDraft);
      setDog((prev) => (prev ? { ...prev, ward_location: wardDraft.trim() || null, admission_status: admissionDraft as any } : null));
      setEditingWard(false);
      toast("success", "Hospital ward & admission status updated");
    } catch (err) {
      toast("error", friendlyError(err, "update ward"));
    } finally {
      setSavingWard(false);
    }
  };

  // Single-dog page: safe to filter Realtime by dog_id directly.
  useEffect(() => {
    if (!dogId) return;

    const channel = supabase
      .channel(`dog-detail-${dogId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "telemetry_readings", filter: `dog_id=eq.${dogId}` },
        (payload) =>
          setReadings((prev) => [...prev, payload.new as TelemetryReading].slice(-HISTORY_LIMIT)),
      )
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "stress_classifications",
          filter: `dog_id=eq.${dogId}`,
        },
        (payload) =>
          setClassifications((prev) =>
            [...prev, payload.new as StressClassification].slice(-HISTORY_LIMIT),
          ),
      )
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "alerts", filter: `dog_id=eq.${dogId}` },
        (payload) => setAlerts((prev) => [payload.new as Alert, ...prev]),
      )
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "clinical_interventions", filter: `dog_id=eq.${dogId}` },
        (payload) => setInterventions((prev) => [payload.new as ClinicalIntervention, ...prev]),
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [dogId]);

  if (loading)
    return (
      <div className="flex flex-col gap-4 p-6">
        <CardSkeleton lines={2} />
        <CardSkeleton lines={4} />
      </div>
    );
  if (error)
    return (
      <p role="alert" className="m-6 rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );
  if (!dog)
    return (
      <div className="p-6">
        <EmptyState>
          We couldn&apos;t find that dog (or they&apos;re not visible to your account).
        </EmptyState>
      </div>
    );

  const latest = classifications[classifications.length - 1] ?? null;
  const latestReading = readings[readings.length - 1] ?? null;

  return (
    <div className="flex flex-col gap-5 p-6 max-w-5xl mx-auto w-full">
      {/* Top Breadcrumb Header Bar */}
      <div className="flex items-center justify-between border-b border-hairline/80 pb-3">
        <Link
          to="/board"
          className="inline-flex items-center gap-1.5 text-xs font-bold text-ink-muted hover:text-brand transition-colors"
        >
          <ArrowLeft size={14} />
          Back to Monitoring board
        </Link>
      </div>

      {/* Hero Header & Telemetry Vitals Card */}
      <Card className="shadow-sm">
        <CardContent className="p-5">
          <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
            <div>
              <p className="m-0 text-xs font-semibold uppercase tracking-wide text-ink-muted">
                {dog.breed ?? "Unknown breed"}
              </p>
              <h1 className="m-0 flex items-center gap-3 text-2xl font-bold text-ink">
                {dog.name} {latest && <StressLevelBadge level={latest.stress_level} />}
              </h1>
            </div>

            {/* Ward & Admission Status Badge Row */}
            <div className="flex flex-wrap items-center gap-2">
              <div className="inline-flex items-center gap-1.5 rounded-lg border border-brand/30 bg-brand-soft px-3 py-1 text-xs font-bold text-brand-strong">
                <MapPin size={13} className="text-brand" />
                <span>{dog.ward_location || "Ward / Cage: Unassigned"}</span>
              </div>
              <span
                className={cn(
                  "rounded-lg px-3 py-1 text-xs font-bold uppercase tracking-wider border",
                  dog.admission_status === "in_surgery"
                    ? "bg-purple-50 text-purple-700 border-purple-200"
                    : dog.admission_status === "recovery"
                      ? "bg-amber-50 text-amber-700 border-amber-200"
                      : dog.admission_status === "admitted"
                        ? "bg-sky-50 text-sky-700 border-sky-200"
                        : "bg-emerald-50 text-emerald-700 border-emerald-200",
                )}
              >
                {dog.admission_status ? dog.admission_status.replace(/_/g, " ") : "Outpatient"}
              </span>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => setEditingWard(!editingWard)}
                className="h-8 px-2 text-xs font-semibold text-ink-muted hover:text-ink border border-hairline"
              >
                <Edit3 size={12} className="mr-1" />
                {editingWard ? "Close" : "Edit Status"}
              </Button>
            </div>
          </div>

          {/* Inline Ward Location & Status Quick-Editor */}
          {editingWard && (
            <div className="mb-4 rounded-xl border border-brand/30 bg-brand-soft/30 p-3.5 flex flex-wrap items-center gap-3 animate-in fade-in-50 duration-150">
              <div className="flex flex-col gap-1 min-w-44 flex-1">
                <label className="text-[11px] font-bold text-ink">Ward / Cage Location</label>
                <Input
                  placeholder="e.g. ICU - Cage 2, Ward A - 4"
                  value={wardDraft}
                  onChange={(e) => setWardDraft(e.target.value)}
                  className="h-8 text-xs bg-surface"
                />
              </div>

              <div className="flex flex-col gap-1 min-w-40 flex-1">
                <label className="text-[11px] font-bold text-ink">Admission Stage</label>
                <Select
                  value={admissionDraft}
                  onChange={(e) => setAdmissionDraft(e.target.value)}
                  className="h-8 text-xs bg-surface"
                >
                  <option value="outpatient">Outpatient</option>
                  <option value="admitted">Admitted (General)</option>
                  <option value="in_surgery">In-Surgery</option>
                  <option value="recovery">Post-Op Recovery</option>
                  <option value="ready_for_discharge">Ready for Discharge</option>
                </Select>
              </div>

              <div className="flex items-center gap-2 self-end pb-0.5">
                <Button
                  size="sm"
                  onClick={handleSaveWard}
                  disabled={savingWard}
                  className="h-8 text-xs font-bold"
                >
                  <Check size={12} className="mr-1" />
                  {savingWard ? "Saving…" : "Update Ward"}
                </Button>
              </div>
            </div>
          )}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <Vital
              label="Heart rate"
              icon={HeartPulse}
              value={latestReading?.heart_rate_bpm}
              unit="bpm"
              series={seriesOf(readings, (r) => r.heart_rate_bpm)}
            />
            <Vital
              label="Respiratory"
              icon={Wind}
              value={latestReading?.respiratory_rate_bpm}
              unit="bpm"
              series={seriesOf(readings, (r) => r.respiratory_rate_bpm)}
            />
            <Vital
              label="Posture"
              icon={Activity}
              value={formatPosture(latestReading?.posture).label}
              series={seriesOf(readings, (r) => r.motion_activity)}
            />
            <Vital
              label="Ambient Temp"
              icon={Thermometer}
              value={latestReading?.ambient_temperature_c}
              unit="°C"
              series={seriesOf(readings, (r) => r.ambient_temperature_c)}
            />
          </div>
          {latestReading && (
            <p className="m-0 mt-3 text-xs text-ink-muted">
              Last updated {new Date(latestReading.captured_at).toLocaleString()}
            </p>
          )}
        </CardContent>
      </Card>

      {/* Sticky Segmented Control Navigation Bar */}
      <div className="sticky top-4 z-20 rounded-2xl border border-hairline bg-surface/90 backdrop-blur-md p-1.5 shadow-sm">
        <div className="flex items-center gap-1 sm:gap-2 overflow-x-auto no-scrollbar" role="tablist">
          {TABS.map((t) => {
            const active = tab === t.id;
            const openCount = t.id === "alerts" ? alerts.filter((a) => a.status === "open").length : 0;
            const Icon = t.icon;
            return (
              <button
                key={t.id}
                type="button"
                role="tab"
                aria-selected={active}
                onClick={() => setTab(t.id)}
                className={cn(
                  "flex items-center gap-2 rounded-xl px-3.5 py-2 text-xs font-bold transition-all duration-150 shrink-0 select-none border",
                  active
                    ? "bg-brand-soft text-brand-strong border-brand/30 shadow-2xs"
                    : "bg-transparent text-ink-muted hover:text-ink hover:bg-surface-alt border-transparent",
                )}
              >
                <Icon size={15} className={cn(active ? "text-brand" : "text-ink-muted/70")} />
                <span>{t.label}</span>
                {openCount > 0 && (
                  <span
                    className={cn(
                      "ml-1 rounded-full px-2 py-0.5 text-[10px] font-extrabold tabular-nums",
                      active ? "bg-brand text-white" : "bg-high-soft text-high-fg",
                    )}
                  >
                    {openCount}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

          {tab === "alerts" && (
            <Card>
              <CardHeader>
                <CardTitle>Alerts</CardTitle>
              </CardHeader>
              <CardContent>
                {alerts.length === 0 ? (
                  <EmptyState>No alerts — {dog.name} is doing great 🐾</EmptyState>
                ) : (
                  alerts.map((a) => (
                    <AlertCard
                      key={a.id}
                      alert={a}
                      dogName={dog.name}
                      onAcknowledge={async (alert) => {
                        const userId = session?.user.id;
                        if (!userId) return;
                        const updated = await acknowledgeAlert(supabase, alert.id, userId);
                        if (updated) {
                          setAlerts((prev) => prev.map((x) => (x.id === updated.id ? updated : x)));
                        }
                      }}
                    />
                  ))
                )}
              </CardContent>
            </Card>
          )}

          {tab === "telemetry" && (
            <Card>
              <CardHeader>
                <CardTitle>Live telemetry</CardTitle>
              </CardHeader>
              <CardContent>
                <TelemetryChart readings={readings} />
              </CardContent>
            </Card>
          )}

          {tab === "interventions" && (
            <Card>
              <CardContent className="p-5">
                <ClinicalInterventionsList
                  dogId={dog.id}
                  clinicId={dog.clinic_id}
                  interventions={interventions}
                  onRecorded={load}
                />
              </CardContent>
            </Card>
          )}

          {tab === "stress" && (
            <>
              <Card>
                <CardHeader className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between py-4">
                  <div>
                    <CardTitle>
                      Stress mix — {stressMixDays === 7 ? "last 7 days" : stressMixDays === 14 ? "last 14 days" : stressMixDays === 30 ? "last 30 days" : "last 3 months"}
                    </CardTitle>
                  </div>
                  <Select
                    value={String(stressMixDays)}
                    onChange={(e) => setStressMixDays(Number(e.target.value))}
                    className="h-9 w-44 text-xs font-medium"
                    aria-label="Select time range"
                  >
                    <option value="7">Last 7 days</option>
                    <option value="14">Last 14 days</option>
                    <option value="30">Last 30 days</option>
                    <option value="90">Last 3 months</option>
                  </Select>
                </CardHeader>
                <CardContent>
                  <StressMixChart summary={mixSummary} />
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Stress timeline</CardTitle>
                </CardHeader>
                <CardContent>
                  <StressTimeline classifications={classifications} />
                </CardContent>
              </Card>
            </>
          )}

          {tab === "notes" && <VetNotes dogId={dog.id} />}

          {tab === "thresholds" && <ThresholdEditor dogId={dog.id} />}

          {tab === "review" && (
            <>
              <ConfirmOverridePanel
                dogId={dog.id}
                latest={latest}
                labels={labels}
                onSaved={load}
              />

              <Card className="mt-5">
                <CardHeader>
                  <CardTitle>Owner-submitted media</CardTitle>
                  <CardDescription>
                    Supplementary context from the owner — not used by the stress classifier.
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  {media.length === 0 ? (
                    <EmptyState>
                      No submissions yet — owners can share photos and short videos from the app 🐾
                    </EmptyState>
                  ) : (
                    <ul className="m-0 flex list-none flex-col gap-4 p-0">
                      {media.map((m) => (
                        <MediaItem
                          key={m.id}
                          media={m}
                          onReviewed={(updated) =>
                            setMedia((prev) => prev.map((x) => (x.id === updated.id ? updated : x)))
                          }
                        />
                      ))}
                    </ul>
                  )}
                </CardContent>
              </Card>
            </>
          )}
    </div>
  );
}
