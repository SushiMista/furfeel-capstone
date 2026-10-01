import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useMemo, useState } from "react";
import { ChevronLeft, ChevronRight, PawPrint, Printer, Search } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  fetchAlertsSince,
  fetchClassificationsSince,
  fetchDogs,
  fetchTelemetrySince,
  getMediaSignedUrl,
} from "../../lib/queries.ts";
import { fetchClinics } from "../../lib/adminQueries.ts";
import {
  buildDogReport,
  buildHighlights,
  type DogReport,
  type VitalSummary,
} from "../../lib/report.ts";
import { StressLevelBadge, stressLevelColor } from "../../components/StressLevelBadge.tsx";
import { TelemetryChart } from "../../components/TelemetryChart.tsx";
import { Card, CardContent } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Input, Label, Select } from "../../components/ui/input.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { cn } from "../../lib/cn.ts";
import type {
  Alert,
  Clinic,
  Dog,
  StressLevel,
  TelemetryReading,
} from "../../../../../packages/shared/types/index.ts";

const PERIODS = [
  { label: "Last 24 hours", hours: 24 },
  { label: "Last 7 days", hours: 24 * 7 },
  { label: "Last 30 days", hours: 24 * 30 },
];

const LEVELS: StressLevel[] = ["calm", "mild", "moderate", "high"];

function MetricRow({
  label,
  unit,
  summary,
  decimals = 0,
}: {
  label: string;
  unit: string;
  summary: VitalSummary | null;
  decimals?: number;
}) {
  const fmt = (n: number) => n.toFixed(decimals);
  return (
    <Tr>
      <Td className="font-medium text-ink">{label}</Td>
      <Td className="text-ink-muted">{unit}</Td>
      <Td className="tabular-nums text-ink-muted">{summary ? fmt(summary.min) : "—"}</Td>
      <Td className="tabular-nums font-semibold text-ink">{summary ? fmt(summary.avg) : "—"}</Td>
      <Td className="tabular-nums text-ink-muted">{summary ? fmt(summary.max) : "—"}</Td>
    </Tr>
  );
}

function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <h3 className="mb-3 mt-6 border-b-2 border-brand pb-1 text-xs font-bold uppercase tracking-widest text-brand-ink">
      {children}
    </h3>
  );
}

function InfoField({ label, value }: { label: string; value: string | null | undefined }) {
  return (
    <p className="m-0 mb-1 text-xs leading-relaxed text-ink">
      <span className="font-bold text-brand-ink">{label}: </span>
      {value && value.trim() !== "" ? value : "—"}
    </p>
  );
}

function InfoPanel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="min-w-[12rem] flex-1 rounded-md bg-brand-soft p-4">
      <p className="m-0 mb-2 text-[10px] font-bold uppercase tracking-widest text-brand">
        {title}
      </p>
      {children}
    </div>
  );
}

function ageYears(birthdate: string | null): number | null {
  if (!birthdate) return null;
  const born = new Date(birthdate);
  if (Number.isNaN(born.getTime())) return null;
  const now = new Date();
  let years = now.getFullYear() - born.getFullYear();
  const beforeBirthdayThisYear =
    now.getMonth() < born.getMonth() ||
    (now.getMonth() === born.getMonth() && now.getDate() < born.getDate());
  if (beforeBirthdayThisYear) years -= 1;
  return years < 0 ? null : years;
}

function capitalize(s: string): string {
  return s.length === 0 ? s : s[0].toUpperCase() + s.slice(1);
}

export function Reports() {
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [clinics, setClinics] = useState<Map<string, Clinic>>(new Map());
  const [dogId, setDogId] = useState<string>("");
  const [dogSearch, setDogSearch] = useState("");
  const [hours, setHours] = useState(24);
  const [report, setReport] = useState<DogReport | null>(null);
  const [readings, setReadings] = useState<TelemetryReading[]>([]);
  const [periodAlerts, setPeriodAlerts] = useState<Alert[]>([]);
  const [period, setPeriod] = useState<{ from: Date; to: Date } | null>(null);
  const [photoUrl, setPhotoUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchDogs(supabase)
      .then((rows) => {
        setDogs(rows);
        if (rows.length > 0) setDogId((prev) => prev || rows[0].id);
      })
      .catch((err) => setError(friendlyError(err, "load dogs")));

    fetchClinics(supabase)
      .then((rows) => setClinics(new Map(rows.map((c) => [c.id, c]))))
      .catch(() => {});
  }, []);

  const dog = dogs.find((d) => d.id === dogId) ?? null;

  // Filtered dog list for searchable combobox
  const filteredDogs = useMemo(() => {
    if (!dogSearch.trim()) return dogs;
    const query = dogSearch.toLowerCase();
    return dogs.filter(
      (d) => d.name.toLowerCase().includes(query) || (d.breed && d.breed.toLowerCase().includes(query)),
    );
  }, [dogs, dogSearch]);

  // Prev / Next Patient Navigation
  const currentIndex = useMemo(() => dogs.findIndex((d) => d.id === dogId), [dogs, dogId]);

  const goToPrevDog = () => {
    if (currentIndex > 0) {
      setDogId(dogs[currentIndex - 1].id);
    }
  };

  const goToNextDog = () => {
    if (currentIndex >= 0 && currentIndex < dogs.length - 1) {
      setDogId(dogs[currentIndex + 1].id);
    }
  };

  useEffect(() => {
    setPhotoUrl(null);
    if (!dog?.photo_path) return;
    let cancelled = false;
    getMediaSignedUrl(supabase, dog.photo_path)
      .then((url) => {
        if (!cancelled) setPhotoUrl(url);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [dog?.photo_path]);

  const generate = useCallback(async () => {
    if (!dogId) return;
    setLoading(true);
    setError(null);
    try {
      const to = new Date();
      const from = new Date(to.getTime() - hours * 3600 * 1000);
      const [periodReadings, classifications, alerts] = await Promise.all([
        fetchTelemetrySince(supabase, dogId, from.toISOString()),
        fetchClassificationsSince(supabase, dogId, from.toISOString()),
        fetchAlertsSince(supabase, dogId, from.toISOString()),
      ]);
      setReport(buildDogReport(periodReadings, classifications, alerts));
      setReadings(periodReadings);
      setPeriodAlerts(alerts);
      setPeriod({ from, to });
    } catch (err) {
      setError(friendlyError(err, "build the report"));
    } finally {
      setLoading(false);
    }
  }, [dogId, hours]);

  useEffect(() => {
    generate();
  }, [generate]);

  const clinic = dog?.clinic_id ? clinics.get(dog.clinic_id) : null;
  const age = dog ? ageYears(dog.birthdate) : null;
  const highlights = report && dog ? buildHighlights(report, dog.name) : [];
  const fmtDate = (d: Date) =>
    d.toLocaleString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between gap-4 print-hidden">
        <h1 className="m-0 text-2xl font-bold text-ink">Analytics &amp; Reports</h1>
        <Button variant="secondary" onClick={() => window.print()}>
          <Printer size={14} className="mr-1.5" /> Print / Save PDF Report
        </Button>
      </div>

      {/* Searchable Dog Finder & Period Controls */}
      <Card className="print-hidden">
        <CardContent className="p-5">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {/* Searchable Dog Finder */}
            <div className="flex flex-col gap-1.5 lg:col-span-2">
              <Label htmlFor="report-dog-search">Search Patient / Select Dog</Label>
              <div className="flex items-center gap-2">
                <div className="relative flex-1">
                  <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-ink-muted" />
                  <Input
                    id="report-dog-search"
                    type="text"
                    placeholder="Search dog by name or breed..."
                    value={dogSearch}
                    onChange={(e) => setDogSearch(e.target.value)}
                    className="pl-8 text-xs"
                  />
                </div>
                <Select
                  id="report-dog"
                  value={dogId}
                  onChange={(e) => setDogId(e.target.value)}
                  className="flex-1 text-xs"
                >
                  {filteredDogs.length === 0 ? (
                    <option value="">No matching dogs</option>
                  ) : (
                    filteredDogs.map((d) => (
                      <option key={d.id} value={d.id}>
                        {d.name} {d.breed ? `(${d.breed})` : ""}
                      </option>
                    ))
                  )}
                </Select>
                {/* Prev / Next Buttons */}
                <div className="flex items-center gap-1">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={goToPrevDog}
                    disabled={currentIndex <= 0}
                    title="Previous Patient"
                    className="h-9 w-9 p-0"
                  >
                    <ChevronLeft size={16} />
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={goToNextDog}
                    disabled={currentIndex >= dogs.length - 1}
                    title="Next Patient"
                    className="h-9 w-9 p-0"
                  >
                    <ChevronRight size={16} />
                  </Button>
                </div>
              </div>
            </div>

            {/* Time Period Selector */}
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="report-period">Report Period</Label>
              <Select
                id="report-period"
                value={hours}
                onChange={(e) => setHours(Number(e.target.value))}
                className="text-xs"
              >
                {PERIODS.map((p) => (
                  <option key={p.hours} value={p.hours}>
                    {p.label}
                  </option>
                ))}
              </Select>
            </div>
          </div>
        </CardContent>
      </Card>

      {error && (
        <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
          {error}
        </p>
      )}
      {loading && <CardSkeleton lines={5} />}

      {!loading && report && dog && period && (
        <Card className="print-plain">
          <CardContent className="p-6">
            {/* Record Masthead */}
            <div className="print-color-exact print-avoid-break flex flex-wrap items-end justify-between gap-4 rounded-md bg-brand p-4 text-white">
              <div>
                <p className="m-0 flex items-center gap-2 text-lg font-bold">
                  <PawPrint size={18} /> FurFeel
                </p>
                <p className="m-0 text-xs">Canine stress monitoring</p>
              </div>
              <div className="text-right">
                <p className="m-0 text-xs font-bold uppercase tracking-widest">Health record</p>
                <p className="m-0 text-xs">Issued {fmtDate(new Date())}</p>
              </div>
            </div>
            <p className="m-0 mt-2 text-xs text-ink-muted">
              Monitoring period {fmtDate(period.from)} – {fmtDate(period.to)} ·{" "}
              {report.readingCount} readings · {report.classificationCount} stress assessments
            </p>

            {/* Patient identity strip */}
            <div className="mt-4 flex items-center gap-4 print-avoid-break">
              <span className="block h-14 w-14 flex-shrink-0 overflow-hidden rounded-pill bg-surface ring-2 ring-brand">
                {photoUrl ? (
                  <img src={photoUrl} alt={dog.name} className="h-full w-full object-cover" />
                ) : (
                  <span className="flex h-full w-full items-center justify-center text-brand">
                    <PawPrint size={24} />
                  </span>
                )}
              </span>
              <div>
                <h2 className="m-0 flex items-center gap-2 text-xl font-bold text-ink">
                  {dog.name}
                  {report.dominantLevel && <StressLevelBadge level={report.dominantLevel} />}
                </h2>
                <p className="m-0 text-sm text-ink-muted">{dog.breed ?? "Breed not recorded"}</p>
              </div>
            </div>

            {/* Patient / clinic info panels */}
            <div className="mt-4 flex flex-wrap gap-3 print-avoid-break">
              <InfoPanel title="Patient">
                <InfoField label="Name" value={dog.name} />
                <InfoField label="Breed" value={dog.breed} />
                <InfoField
                  label="Sex"
                  value={dog.sex && dog.sex !== "unknown" ? capitalize(dog.sex) : null}
                />
                <InfoField
                  label="Date of birth"
                  value={dog.birthdate ? `${dog.birthdate}${age !== null ? ` (${age} y)` : ""}` : null}
                />
                <InfoField
                  label="Weight"
                  value={dog.weight_kg != null ? `${dog.weight_kg} kg` : null}
                />
              </InfoPanel>
              <InfoPanel title="Veterinary clinic">
                {clinic ? (
                  <>
                    <InfoField label="Clinic" value={clinic.name} />
                    <InfoField label="Address" value={clinic.address} />
                    <InfoField label="Contact" value={clinic.contact_number} />
                  </>
                ) : (
                  <p className="m-0 text-xs text-ink-muted">Home monitoring — no clinic linked.</p>
                )}
              </InfoPanel>
            </div>

            {report.readingCount === 0 ? (
              <EmptyState>No readings in this period — nothing to summarize yet 🐾</EmptyState>
            ) : (
              <>
                <SectionTitle>Monitoring summary</SectionTitle>
                <p className="m-0 text-sm text-ink">
                  {report.readingCount} readings
                  {report.invalidReadingCount > 0 &&
                    ` (${report.invalidReadingCount} flagged invalid)`}
                  , {report.classificationCount} stress classifications, {report.alertCount} alerts (
                  {report.openAlertCount} still open).
                </p>

                {/* 🫀 Physiological Vital Signs Section */}
                <SectionTitle>Physiological Vital Signs</SectionTitle>
                <div className="max-w-2xl print-avoid-break">
                  <Table>
                    <THead>
                      <Tr className="border-t-0">
                        <Th>Vital Sign</Th>
                        <Th>Unit</Th>
                        <Th>Min</Th>
                        <Th>Average</Th>
                        <Th>Max</Th>
                      </Tr>
                    </THead>
                    <TBody>
                      <MetricRow label="Heart rate" unit="bpm" summary={report.heartRate} />
                      <MetricRow
                        label="Respiratory rate"
                        unit="breaths/min"
                        summary={report.respiratoryRate}
                      />
                    </TBody>
                  </Table>
                </div>

                {/* 🐾 Physical Movement & Activity Assessment Section */}
                <SectionTitle>Physical Movement &amp; Activity</SectionTitle>
                <div className="max-w-2xl print-avoid-break">
                  <Table>
                    <THead>
                      <Tr className="border-t-0">
                        <Th>Metric</Th>
                        <Th>Unit</Th>
                        <Th>Min</Th>
                        <Th>Average</Th>
                        <Th>Max</Th>
                      </Tr>
                    </THead>
                    <TBody>
                      <MetricRow
                        label="Motion activity"
                        unit="index 0–1"
                        summary={report.motion}
                        decimals={2}
                      />
                    </TBody>
                  </Table>
                </div>

                {/* 🌡️ Ambient Environment Context Section */}
                <SectionTitle>Ambient Environment Context</SectionTitle>
                <div className="max-w-2xl print-avoid-break">
                  <Table>
                    <THead>
                      <Tr className="border-t-0">
                        <Th>Parameter</Th>
                        <Th>Unit</Th>
                        <Th>Min</Th>
                        <Th>Average</Th>
                        <Th>Max</Th>
                      </Tr>
                    </THead>
                    <TBody>
                      <MetricRow
                        label="Ambient temperature"
                        unit="°C"
                        summary={report.ambientTemperature}
                        decimals={1}
                      />
                      <MetricRow label="Humidity" unit="%" summary={report.humidity} />
                    </TBody>
                  </Table>
                </div>

                <SectionTitle>Telemetry trends</SectionTitle>
                <div className="print-avoid-break">
                  <TelemetryChart readings={readings} />
                </div>

                {/* Stress distribution */}
                <SectionTitle>Stress distribution</SectionTitle>
                <div className="max-w-2xl print-avoid-break">
                  <Table>
                    <THead>
                      <Tr className="border-t-0">
                        <Th>Level</Th>
                        <Th>Readings</Th>
                        <Th>Share</Th>
                        <Th></Th>
                      </Tr>
                    </THead>
                    <TBody>
                      {LEVELS.map((level) => {
                        const count = report.stressBreakdown[level];
                        const pct =
                          report.classificationCount > 0
                            ? Math.round((count / report.classificationCount) * 100)
                            : 0;
                        return (
                          <Tr key={level}>
                            <Td>
                              <StressLevelBadge level={level} />
                            </Td>
                            <Td className="tabular-nums">{count}</Td>
                            <Td className="tabular-nums text-ink-muted">{pct}%</Td>
                            <Td className="w-32">
                              <div className="print-color-exact h-2.5 w-full overflow-hidden rounded-pill bg-surface-alt">
                                <div
                                  className="print-color-exact h-full rounded-pill transition-[width] duration-slow"
                                  style={{ width: `${pct}%`, backgroundColor: stressLevelColor(level) }}
                                />
                              </div>
                            </Td>
                          </Tr>
                        );
                      })}
                    </TBody>
                  </Table>
                </div>

                {/* Alerts in this period */}
                <SectionTitle>Alerts in this period</SectionTitle>
                {periodAlerts.length === 0 ? (
                  <p className="m-0 text-sm text-ink">
                    No alerts were raised in this period.
                  </p>
                ) : (
                  <>
                    <div className="print-avoid-break">
                      <Table>
                        <THead>
                          <Tr className="border-t-0">
                            <Th>Date</Th>
                            <Th>Severity</Th>
                            <Th>Alert</Th>
                          </Tr>
                        </THead>
                        <TBody>
                          {periodAlerts.slice(0, 20).map((a) => (
                            <Tr key={a.id}>
                              <Td className="whitespace-nowrap tabular-nums text-ink-muted">
                                {fmtDate(new Date(a.created_at))}
                              </Td>
                              <Td>
                                <span
                                  className={cn(
                                    "text-xs font-bold capitalize",
                                    a.severity === "critical"
                                      ? "text-high-fg"
                                      : a.severity === "warning"
                                        ? "text-moderate-fg"
                                        : "text-ink-muted",
                                  )}
                                >
                                  {a.severity}
                                </span>
                              </Td>
                              <Td>{a.message}</Td>
                            </Tr>
                          ))}
                        </TBody>
                      </Table>
                    </div>
                    {periodAlerts.length > 20 && (
                      <p className="m-0 mt-2 text-xs text-ink-muted">
                        Showing the 20 most recent of {periodAlerts.length} alerts.
                      </p>
                    )}
                  </>
                )}

                <SectionTitle>Abnormal-pattern highlights</SectionTitle>
                {highlights.length === 0 ? (
                  <p className="m-0 text-sm text-ink">
                    Nothing flagged in this period — readings, classifications, and alerts all
                    look routine.
                  </p>
                ) : (
                  <ul className="m-0 flex list-disc flex-col gap-1 pl-5 text-sm text-ink">
                    {highlights.map((h) => (
                      <li key={h}>{h}</li>
                    ))}
                  </ul>
                )}
              </>
            )}

            <p className="mb-0 mt-6 border-t border-hairline pt-3 text-xs text-ink-muted">
              Decision support — not a diagnosis. FurFeel reports summarize wearable telemetry
              to support veterinary review and can be shared with other clinics as part of the
              dog&apos;s record.
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
