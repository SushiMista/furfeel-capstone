/**
 * ADDED (ISO 25010 performance-efficiency evidence, docs/20): in-session
 * response-time samples with p50/p95 logged to the console after each
 * measurement. Open devtools and read the `[perf]` lines — no backend, no
 * third-party telemetry (privacy stance, docs/12).
 */
const samples = new Map<string, number[]>();

/** Nearest-rank percentile; expects a sorted ascending array. */
export function percentile(sortedMs: number[], p: number): number {
  if (sortedMs.length === 0) return 0;
  const rank = Math.ceil((p / 100) * sortedMs.length);
  return sortedMs[Math.min(rank, sortedMs.length) - 1];
}

export async function timed<T>(metric: string, fn: () => Promise<T>): Promise<T> {
  const startedAt = performance.now();
  try {
    return await fn();
  } finally {
    const ms = Math.round(performance.now() - startedAt);
    const list = samples.get(metric) ?? [];
    list.push(ms);
    samples.set(metric, list);
    const sorted = [...list].sort((a, b) => a - b);
    console.log(
      `[perf] ${metric} ${ms}ms (session n=${sorted.length} ` +
        `p50=${percentile(sorted, 50)}ms p95=${percentile(sorted, 95)}ms)`,
    );
  }
}
