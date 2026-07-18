import { useCallback, useEffect, useState } from "react";
import { PawPrint, Printer } from "lucide-react";
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
import { Label, Select } from "../../components/ui/input.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import type {
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

function VitalRow({ label, unit, summary }: { label: string; unit: string; summary: VitalSummary | null }) {
  return (
    <Tr>
      <Td>{label}</Td>
      <Td className="tabular-nums">{summary ? `${summary.avg} ${unit}` : "—"}</Td>
      <Td className="tabular-nums text-ink-muted">
        {summary ? `${summary.min}–${summary.max} ${unit}` : "—"}
      </Td>
    </Tr>
  );
}

/** Uppercase section rule (docs/19 typography) so the record reads as a
 * structured document, on screen and on paper. */
function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <h3 className="mb-3 mt-6 border-b-2 border-brand pb-1 text-xs font-bold uppercase tracking-widest text-brand-ink">
      {children}
    </h3>
  );
}

/** Reports (docs/05 §3): the FurFeel Health Record — a per-dog period summary
 * formatted as a document a clinic can print and file. Decision support, not
 * diagnosis. */
export function Reports() {
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [clinicNames, setClinicNames] = useState<Map<string, string>>(new Map());
  const [dogId, setDogId] = useState<string>("");
  const [hours, setHours] = useState(24);
  const [report, setReport] = useState<DogReport | null>(null);
  const [readings, setReadings] = useState<TelemetryReading[]>([]);
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
      .catch((err) => setError(err instanceof Error ? err.message : "Failed to load dogs"));
    // clinics_select_authenticated: any signed-in staff member can resolve names.
    fetchClinics(supabase)
      .then((rows) => setClinicNames(new Map(rows.map((c) => [c.id, c.name]))))
      .catch(() => {});
  }, []);

  const dog = dogs.find((d) => d.id === dogId) ?? null;

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
      setPeriod({ from, to });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to build report");
    } finally {
      setLoading(false);
    }
  }, [dogId, hours]);

  useEffect(() => {
    generate();
  }, [generate]);

  const clinicName = dog?.clinic_id ? clinicNames.get(dog.clinic_id) : null;
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
        <h1 className="m-0 text-2xl font-bold text-ink">Reports</h1>
        <Button variant="secondary" onClick={() => window.print()}>
          <Printer size={14} /> Print / save PDF
        </Button>
      </div>

      <Card className="print-hidden">
        <CardContent className="flex flex-wrap items-end gap-5 p-5">
          <div className="flex flex-col gap-1">
            <Label htmlFor="report-dog">Dog</Label>
            <Select id="report-dog" value={dogId} onChange={(e) => setDogId(e.target.value)}>
              {dogs.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.name}
                </option>
              ))}
            </Select>
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="report-period">Period</Label>
            <Select
              id="report-period"
              value={hours}
              onChange={(e) => setHours(Number(e.target.value))}
            >
              {PERIODS.map((p) => (
                <option key={p.hours} value={p.hours}>
                  {p.label}
                </option>
              ))}
            </Select>
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
            {/* ── Record masthead ──────────────────────────────────────── */}
            <div className="flex flex-wrap items-start justify-between gap-4 rounded-md bg-brand-soft p-4 print-avoid-break">
              <div className="flex items-center gap-4">
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
                  <p className="m-0 text-xs font-bold uppercase tracking-widest text-brand">
                    FurFeel Health Record
                  </p>
                  <h2 className="m-0 flex items-center gap-2 text-xl font-bold text-ink">
                    {dog.name}
                    {report.dominantLevel && <StressLevelBadge level={report.dominantLevel} />}
                  </h2>
                  <p className="m-0 text-sm text-ink-muted">{dog.breed ?? "Breed not recorded"}</p>
                </div>
              </div>
              <div className="text-right text-xs text-ink-muted">
                <p className="m-0 font-semibold text-ink">
                  {clinicName ?? "Home monitoring — no clinic linked"}
                </p>
                <p className="m-0">
                  Period: {fmtDate(period.from)} — {fmtDate(period.to)}
                </p>
                <p className="m-0">Generated {fmtDate(new Date())}</p>
              </div>
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

                <SectionTitle>Vitals</SectionTitle>
                <div className="max-w-lg print-avoid-break">
                  <Table>
                    <THead>
                      <Tr className="border-t-0">
                        <Th>Vital</Th>
                        <Th>Average</Th>
                        <Th>Range</Th>
                      </Tr>
                    </THead>
                    <TBody>
                      <VitalRow label="Heart rate" unit="bpm" summary={report.heartRate} />
                      <VitalRow label="Respiratory rate" unit="bpm" summary={report.respiratoryRate} />
                      <VitalRow label="Body temperature" unit="°C" summary={report.temperature} />
                    </TBody>
                  </Table>
                </div>

                <SectionTitle>Vitals trend</SectionTitle>
                <div className="print-avoid-break">
                  <TelemetryChart readings={readings} />
                </div>

                <SectionTitle>Stress distribution</SectionTitle>
                <div className="flex max-w-lg flex-col gap-2 print-avoid-break">
                  {LEVELS.map((level) => {
                    const count = report.stressBreakdown[level];
                    const pct =
                      report.classificationCount > 0
                        ? Math.round((count / report.classificationCount) * 100)
                        : 0;
                    return (
                      <div
                        key={level}
                        className="grid grid-cols-[7rem_1fr_5rem] items-center gap-3"
                      >
                        <StressLevelBadge level={level} />
                        <div className="h-3 overflow-hidden rounded-pill bg-surface-alt">
                          <div
                            className="h-full rounded-pill transition-[width] duration-slow"
                            style={{ width: `${pct}%`, backgroundColor: stressLevelColor(level) }}
                          />
                        </div>
                        <span className="text-sm tabular-nums text-ink-muted">
                          {count} ({pct}%)
                        </span>
                      </div>
                    );
                  })}
                </div>

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
