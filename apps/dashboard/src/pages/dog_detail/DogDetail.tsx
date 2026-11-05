import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useParams, useSearchParams } from "react-router-dom";
import {
  Activity,
  ArrowLeft,
  BarChart3,
  BellRing,
  Check,
  ChevronDown,
  Edit3,
  FileText,
  HeartPulse,
  MapPin,
  MessageSquare,
  PawPrint,
  Pill,
    Thermometer,
  Users,
  Wind,
  type LucideIcon,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  acknowledgeAlerts,
  fetchClassificationHistory,
  fetchClinicalInterventions,
  fetchDailyStressSummary,
  collarName,
  fetchDog,
  fetchDogOwners,
  fetchDeviceForDog,
  fetchRecentAlerts,
  fetchTelemetryHistory,
  fetchVetNotes,
  getMediaSignedUrl,
  updateDogWardAndAdmission,
  type DailyStressSummaryRow,
  type VetNoteWithAuthor,
} from "../../lib/queries.ts";
import { Conversation } from "../messages/Messages.tsx";
import { useAuth } from "../../lib/useAuth.ts";
import { TelemetryChart } from "../../components/TelemetryChart.tsx";
import { StressMixChart } from "../../components/StressMixChart.tsx";
import { StressTimeline } from "../../components/StressTimeline.tsx";
import { StressCalendar } from "../../components/StressCalendar.tsx";
import { MicroSparkline } from "../../components/MicroSparkline.tsx";
import { AlertCard } from "../../components/AlertCard.tsx";
import { VetNotes } from "../../components/VetNotes.tsx";
import { ClinicalInterventionsList } from "../../components/ClinicalInterventionsList.tsx";
import { ManageDogOwners } from "../../components/ManageDogOwners.tsx";
import { HarnessBattery } from "../../components/HarnessBattery.tsx";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Input, Select } from "../../components/ui/input.tsx";
import { Button } from "../../components/ui/button.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { useToast } from "../../components/ui/toast.tsx";
import { cn } from "../../lib/cn.ts";
import { dogTint } from "../../lib/dogTint.ts";
import { groupAlerts } from "../../lib/alertCopy.ts";
import type {
  Alert,
  ClinicalIntervention,
  Dog,
  Device,
  StressClassification,
  StressLevel,
  TelemetryReading,
  User,
} from "../../../../../packages/shared/types/index.ts";

import { formatPosture } from "../../lib/posture.ts";
import { timeAgo } from "../../lib/time.ts";

const HISTORY_LIMIT = 50;

/** Section tabs (docs/05): redesigned with icons & matching Board Controls style. */
const TABS = [
  { id: "telemetry", label: "Live telemetry", icon: Activity },
  { id: "alerts", label: "Alert history", icon: BellRing },
  { id: "interventions", label: "Treatments & Meds", icon: Pill },
  { id: "stress", label: "Stress history", icon: BarChart3 },
  { id: "notes", label: "Vet notes", icon: FileText },
  { id: "messages", label: "Messages", icon: MessageSquare },
] as const;
type TabId = (typeof TABS)[number]["id"];

/** Status hero colours, matching the mobile Home hero (ADR-023). */
const LEVELS: Record<StressLevel, { phrase: string; hero: string }> = {
  calm: { phrase: "is calm", hero: "bg-calm-soft text-calm-fg" },
  mild: { phrase: "is mildly stressed", hero: "bg-mild-soft text-mild-fg" },
  moderate: { phrase: "is moderately stressed", hero: "bg-moderate-soft text-moderate-fg" },
  high: { phrase: "is highly stressed", hero: "bg-high-soft text-high-fg" },
};

function DogPhoto({ dog }: { dog: Dog }) {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!dog.photo_path) return;
    let cancelled = false;
    getMediaSignedUrl(supabase, dog.photo_path)
      .then((signed) => {
        if (!cancelled) setUrl(signed);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [dog.photo_path]);

  return url ? (
    <img src={url} alt="" className="h-14 w-14 shrink-0 rounded-xl object-cover" />
  ) : (
    <div className={cn("flex h-14 w-14 shrink-0 items-center justify-center rounded-xl text-white", dogTint(dog.id))}>
      <PawPrint size={26} aria-hidden="true" />
    </div>
  );
}

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
    <div className="flex min-w-28 flex-1 flex-col gap-1.5 rounded-xl border border-hairline bg-surface px-4 py-3 shadow-xs">
      <div className="flex items-center gap-1.5 text-xs font-medium text-ink-muted">
        <Icon size={14} aria-hidden="true" className="text-brand" />
        {label}
      </div>
      <div className="text-xl sm:text-2xl font-bold leading-tight tabular-nums text-ink truncate">
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
  const [notes, setNotes] = useState<VetNoteWithAuthor[]>([]);
  const [interventions, setInterventions] = useState<ClinicalIntervention[]>([]);
  const [owners, setOwners] = useState<User[]>([]);
  const [device, setDevice] = useState<Device | null>(null);
  const [editingOwners, setEditingOwners] = useState(false);
  const [editingWard, setEditingWard] = useState(false);
  const [wardDraft, setWardDraft] = useState("");
  const [admissionDraft, setAdmissionDraft] = useState<string>("outpatient");
  const [savingWard, setSavingWard] = useState(false);
  const [tab, setTabState] = useState<TabId>(() => {
    const defaultTab = searchParams.get("tab") as TabId;
    return TABS.some((t) => t.id === defaultTab) ? defaultTab : "telemetry";
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
      const [dogRow, history, classHistory, recentAlerts, mixRows, interventionRows, ownerList, deviceRow, noteRows] = await Promise.all([
        fetchDog(supabase, dogId),
        fetchTelemetryHistory(supabase, dogId, HISTORY_LIMIT),
        fetchClassificationHistory(supabase, dogId, HISTORY_LIMIT),
        fetchRecentAlerts(supabase, dogId),
        fetchDailyStressSummary(supabase, dogId, stressMixDays),
        fetchClinicalInterventions(supabase, dogId),
        fetchDogOwners(supabase, dogId),
        fetchDeviceForDog(supabase, dogId),
        fetchVetNotes(supabase, dogId),
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
      setInterventions(interventionRows);
      setOwners(ownerList);
      setDevice(deviceRow);
      setNotes(noteRows);
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

  const alertGroups = useMemo(() => groupAlerts(alerts), [alerts]);
  const openGroups = alertGroups.filter((g) => g.latest.status === "open");

  const acknowledge = async (ids: string[]) => {
    const userId = session?.user.id;
    if (!userId) return;
    const updated = await acknowledgeAlerts(supabase, ids, userId);
    const byId = new Map(updated.map((a) => [a.id, a]));
    setAlerts((prev) => prev.map((a) => byId.get(a.id) ?? a));
  };

  const renderAlertGroup = ({ latest: alert, earlier }: (typeof alertGroups)[number]) => (
    <AlertCard
      key={alert.id}
      alert={alert}
      earlier={earlier}
      onAcknowledge={() =>
        acknowledge([alert, ...earlier].filter((a) => a.status === "open").map((a) => a.id))
      }
    />
  );

  const handleSaveWard = async () => {
    if (!dogId) return;
    setSavingWard(true);
    try {
      const updatedWard = wardDraft.trim() || null;
      await updateDogWardAndAdmission(supabase, dogId, updatedWard, admissionDraft);
      setDog((prev) => (prev ? { ...prev, ward_location: updatedWard, admission_status: admissionDraft as any } : null));
      setEditingWard(false);
      toast("success", `✨ Updated ward location & admission status for ${dog?.name || "patient"}`);
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
  const level = latest?.stress_level;
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

      {/* Status hero, matching mobile Home (ADR-023) */}
      <div className={cn("rounded-2xl p-4", level ? LEVELS[level].hero : "bg-surface-alt text-ink")}>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex min-w-0 items-center gap-3">
            <DogPhoto dog={dog} />
            <div className="min-w-0">
              <h1 className="m-0 text-xl font-bold">
                {dog.name} {level ? LEVELS[level].phrase : "has no stress reading yet"}
              </h1>
              <p className="m-0 text-xs text-ink-muted">
                {[
                  dog.breed,
                  device && `Collar: ${collarName(device)}`,
                  latestReading && timeAgo(latestReading.captured_at),
                ]
                  .filter(Boolean)
                  .join(" · ")}
              </p>
            </div>
          </div>
          <Button
            size="sm"
            onClick={() => {
              setTab("messages");
              document.getElementById("dog-sections")?.scrollIntoView({ behavior: "smooth" });
            }}
          >
            <MessageSquare size={14} aria-hidden="true" />
            Message owner
          </Button>
        </div>

        <div className="mt-3 flex flex-wrap items-center gap-2 border-t border-ink/10 pt-3 text-xs text-ink">
          <span className="inline-flex items-center gap-1 font-medium">
            <MapPin size={13} aria-hidden="true" />
            {dog.ward_location || "No ward assigned"}
          </span>
          <span className="capitalize text-ink-muted">
            · {dog.admission_status ? dog.admission_status.replace(/_/g, " ") : "outpatient"}
          </span>
          <HarnessBattery
            percent={latestReading?.battery_percent ?? device?.battery_percent}
            reportedAt={latestReading?.battery_percent != null ? latestReading.captured_at : null}
            offline={device?.status === "offline"}
          />
          <span className="ml-auto flex flex-wrap items-center gap-2">
            <Button size="sm" variant="ghost" onClick={() => setEditingWard(!editingWard)}>
              <Edit3 size={12} aria-hidden="true" />
              {editingWard ? "Close" : "Edit status"}
            </Button>
            <details className="group relative">
              <summary className="inline-flex cursor-pointer list-none items-center gap-1.5 rounded-lg px-2 py-1.5 text-xs font-semibold text-ink hover:bg-surface/60 [&::-webkit-details-marker]:hidden">
                <Users size={13} aria-hidden="true" />
                {owners.length === 1 ? "1 owner" : `${owners.length} owners`}
                <ChevronDown
                  size={13}
                  aria-hidden="true"
                  className="transition-transform group-open:rotate-180"
                />
              </summary>
              <div className="absolute right-0 z-30 mt-1 w-64 rounded-xl border border-hairline bg-surface p-2 shadow-lg">
                <ul className="m-0 list-none p-0">
                  {owners.map((o) => (
                    <li key={o.id} className="truncate px-2 py-1">
                      <span className="block truncate font-medium text-ink">{o.name}</span>
                      <span className="block truncate text-ink-muted">{o.email}</span>
                    </li>
                  ))}
                </ul>
                <Button
                  size="sm"
                  variant="secondary"
                  className="mt-1 w-full"
                  onClick={() => setEditingOwners(true)}
                >
                  Manage owners
                </Button>
              </div>
            </details>
          </span>
        </div>
      </div>

          {/* Inline Ward Location & Status Quick-Editor */}
          {editingWard && (
            <div className="rounded-xl border border-brand/30 bg-brand-soft/30 p-3.5 flex flex-wrap items-center gap-3 animate-in fade-in-50 duration-150">
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

          {editingOwners && <ManageDogOwners dog={dog} owners={owners} onClose={() => setEditingOwners(false)} onSaved={(updated) => {
            setOwners(updated);
            setEditingOwners(false);
            toast("success", "Owner accounts added to this dog.");
          }} />}


      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Vital
          label="Heart rate"
          icon={HeartPulse}
          value={latestReading?.heart_rate_bpm}
          unit="bpm"
          series={seriesOf(readings, (r) => r.heart_rate_bpm)}
        />
        <Vital
          label="Breathing"
          icon={Wind}
          value={latestReading?.respiratory_rate_bpm}
          unit="br/min"
          series={seriesOf(readings, (r) => r.respiratory_rate_bpm)}
        />
        <Vital
          label="Posture"
          icon={Activity}
          value={formatPosture(latestReading?.posture).label}
          series={seriesOf(readings, (r) => r.motion_activity)}
        />
        <Vital
          label="Room temp"
          icon={Thermometer}
          value={latestReading?.ambient_temperature_c}
          unit="°C"
          series={seriesOf(readings, (r) => r.ambient_temperature_c)}
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-[3fr_2fr]">
        <Card>
          <CardContent className="p-4">
            <StressCalendar dogId={dog.id} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Open alerts and notes</CardTitle>
          </CardHeader>
          <CardContent>
            {openGroups.length === 0 ? (
              <p className="m-0 mb-2 text-sm text-ink-muted">No open alerts</p>
            ) : (
              openGroups.map(renderAlertGroup)
            )}
            {notes[0] && (
              <p className="m-0 text-xs text-ink-muted">
                Vet note, {timeAgo(notes[0].created_at)}: {notes[0].note}
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Sticky Segmented Control Navigation Bar */}
      <div id="dog-sections" className="sticky top-4 z-20 scroll-mt-4 rounded-2xl border border-hairline bg-surface/90 backdrop-blur-md p-1.5 shadow-sm">
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
                <CardTitle>Alert history</CardTitle>
              </CardHeader>
              <CardContent>
                {alerts.length === 0 ? (
                  <EmptyState>No alerts — {dog.name} is doing great 🐾</EmptyState>
                ) : (
                  alertGroups.map(renderAlertGroup)
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

          {tab === "messages" && (
            <Card className="h-[32rem] overflow-hidden">
              <Conversation dog={dog} embedded />
            </Card>
          )}
    </div>
  );
}
