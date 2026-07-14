import { useCallback, useEffect, useState } from "react";
import { Printer } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  fetchAlertsSince,
  fetchClassificationsSince,
  fetchDogs,
  fetchTelemetrySince,
} from "../../lib/queries.ts";
import { buildDogReport, type DogReport, type VitalSummary } from "../../lib/report.ts";
import { StressLevelBadge, stressLevelColor } from "../../components/StressLevelBadge.tsx";
import { Card, CardContent } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Label, Select } from "../../components/ui/input.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import type { Dog, StressLevel } from "../../../../../packages/shared/types/index.ts";

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

/** Reports (docs/05): per-dog period summary for clinic review and printing.
 * Decision support, not diagnosis. */
export function Reports() {
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [dogId, setDogId] = useState<string>("");
  const [hours, setHours] = useState(24);
  const [report, setReport] = useState<DogReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchDogs(supabase)
      .then((rows) => {
        setDogs(rows);
        if (rows.length > 0) setDogId((prev) => prev || rows[0].id);
      })
      .catch((err) => setError(err instanceof Error ? err.message : "Failed to load dogs"));
  }, []);

  const generate = useCallback(async () => {
    if (!dogId) return;
    setLoading(true);
    setError(null);
    try {
      const since = new Date(Date.now() - hours * 3600 * 1000).toISOString();
      const [readings, classifications, alerts] = await Promise.all([
        fetchTelemetrySince(supabase, dogId, since),
        fetchClassificationsSince(supabase, dogId, since),
        fetchAlertsSince(supabase, dogId, since),
      ]);
      setReport(buildDogReport(readings, classifications, alerts));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to build report");
    } finally {
      setLoading(false);
    }
  }, [dogId, hours]);

  useEffect(() => {
    generate();
  }, [generate]);

  const dog = dogs.find((d) => d.id === dogId) ?? null;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between gap-4">
        <h1 className="m-0 text-2xl font-bold text-ink">Reports</h1>
        <Button variant="secondary" className="print-hidden" onClick={() => window.print()}>
          <Printer size={14} /> Print
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

      {!loading && report && dog && (
        <Card>
          <CardContent className="p-5">
            <p className="m-0 mb-1 text-xs font-semibold uppercase tracking-wide text-ink-muted">
              {PERIODS.find((p) => p.hours === hours)?.label} · generated{" "}
              {new Date().toLocaleString()}
            </p>
            <h2 className="m-0 mb-4 flex items-center gap-3 text-xl font-semibold text-ink">
              {dog.name} {report.dominantLevel && <StressLevelBadge level={report.dominantLevel} />}
            </h2>

            {report.readingCount === 0 ? (
              <EmptyState>No readings in this period — nothing to summarize yet 🐾</EmptyState>
            ) : (
              <>
                <p className="text-sm text-ink">
                  {report.readingCount} readings
                  {report.invalidReadingCount > 0 &&
                    ` (${report.invalidReadingCount} flagged invalid)`}
                  , {report.classificationCount} stress classifications, {report.alertCount} alerts (
                  {report.openAlertCount} still open).
                </p>

                <h3 className="mb-2 mt-5 text-xs font-semibold uppercase tracking-wide text-ink-muted">
                  Vitals
                </h3>
                <div className="max-w-lg">
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

                <h3 className="mb-2 mt-5 text-xs font-semibold uppercase tracking-wide text-ink-muted">
                  Stress levels
                </h3>
                <div className="flex max-w-lg flex-col gap-2">
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
              </>
            )}

            <p className="mb-0 mt-5 text-xs text-ink-muted">
              FurFeel reports summarize wearable telemetry as decision support for veterinary
              review — they are not a diagnosis.
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
