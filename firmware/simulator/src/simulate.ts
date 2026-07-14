// FurFeel device simulator (docs/07 Sensor Data Pipeline). Stands in for the ESP32 firmware
// before hardware exists: posts one aggregated telemetry payload every ~10s (the doc's default
// transmit interval) to the deployed telemetry-intake Edge Function.
import type { Posture, TelemetryPayload } from "../../../packages/shared/types/telemetry.ts";

interface SimulatorConfig {
  functionUrl: string;
  deviceCode: string;
  deviceKey: string;
  intervalMs: number;
  sweep: boolean;
  sweepTicks: number;
  maxTicks: number | null;
}

const DEFAULT_INTERVAL_MS = 10_000;
const DEFAULT_SWEEP_TICKS = 18; // ~3 minutes at the default 10s interval

function printUsageAndExit(message?: string): never {
  if (message) console.error(`Error: ${message}\n`);
  console.error(
    [
      "Usage: npm start -- [options]",
      "",
      "Options (or set the equivalent FURFEEL_* env var / .env entry):",
      "  --function-url=<url>   Edge Function URL (FURFEEL_FUNCTION_URL)",
      "  --device-code=<code>   Device code, e.g. FURFEEL-DEV-0001 (FURFEEL_DEVICE_CODE)",
      "  --device-key=<key>     Plaintext ingest key (FURFEEL_DEVICE_KEY)",
      "  --interval-ms=<n>      Ms between payloads (default 10000, docs/07 default)",
      "  --sweep                Ramp readings from calm to high over --sweep-ticks, then hold high",
      "  --sweep-ticks=<n>      Ticks to reach 'high' when sweeping (default 18)",
      "  --max-ticks=<n>        Stop automatically after n payloads (default: run forever)",
      "  --help                 Show this message",
    ].join("\n"),
  );
  process.exit(message ? 1 : 0);
}

function parseArgs(argv: string[]): Record<string, string | boolean> {
  const out: Record<string, string | boolean> = {};
  for (const arg of argv) {
    if (arg === "--help" || arg === "-h") out.help = true;
    else if (arg === "--sweep") out.sweep = true;
    else if (arg.startsWith("--")) {
      const eq = arg.indexOf("=");
      if (eq === -1) out[arg.slice(2)] = true;
      else out[arg.slice(2, eq)] = arg.slice(eq + 1);
    }
  }
  return out;
}

function readConfig(): SimulatorConfig {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) printUsageAndExit();

  const functionUrl = (args["function-url"] as string) ?? process.env.FURFEEL_FUNCTION_URL;
  const deviceCode = (args["device-code"] as string) ?? process.env.FURFEEL_DEVICE_CODE;
  const deviceKey = (args["device-key"] as string) ?? process.env.FURFEEL_DEVICE_KEY;

  if (!functionUrl) printUsageAndExit("--function-url or FURFEEL_FUNCTION_URL is required");
  if (!deviceCode) printUsageAndExit("--device-code or FURFEEL_DEVICE_CODE is required");
  if (!deviceKey) printUsageAndExit("--device-key or FURFEEL_DEVICE_KEY is required");

  return {
    functionUrl,
    deviceCode,
    deviceKey,
    intervalMs: Number(args["interval-ms"] ?? DEFAULT_INTERVAL_MS),
    sweep: Boolean(args.sweep),
    sweepTicks: Number(args["sweep-ticks"] ?? DEFAULT_SWEEP_TICKS),
    maxTicks: args["max-ticks"] !== undefined ? Number(args["max-ticks"]) : null,
  };
}

// docs/08 Global Default Baselines / worked example ranges, used as the two ends of the sweep.
const CALM = { heart_rate_bpm: 90, respiratory_rate_bpm: 22, body_temperature_c: 38.5, motion_activity: 0.25 };
const HIGH = { heart_rate_bpm: 155, respiratory_rate_bpm: 46, body_temperature_c: 39.6, motion_activity: 0.8 };

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function jitter(value: number, amount: number): number {
  return value + (Math.random() * 2 - 1) * amount;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

/** t=0 is calm-range, t=1 is high-range. Non-sweep mode stays at t=0 (steady calm) with jitter. */
function buildPayload(config: SimulatorConfig, tick: number): TelemetryPayload {
  const t = config.sweep ? clamp(tick / config.sweepTicks, 0, 1) : 0;

  const heart_rate_bpm = Math.round(jitter(lerp(CALM.heart_rate_bpm, HIGH.heart_rate_bpm, t), 3));
  const respiratory_rate_bpm = Math.round(
    jitter(lerp(CALM.respiratory_rate_bpm, HIGH.respiratory_rate_bpm, t), 2),
  );
  const body_temperature_c = Number(
    jitter(lerp(CALM.body_temperature_c, HIGH.body_temperature_c, t), 0.1).toFixed(1),
  );
  const motion_activity = Number(
    clamp(jitter(lerp(CALM.motion_activity, HIGH.motion_activity, t), 0.05), 0, 1).toFixed(3),
  );
  const posture: Posture = motion_activity > 0.6 ? "moving" : t > 0.3 ? "standing" : "lying";

  return {
    device_code: config.deviceCode,
    captured_at: new Date().toISOString(),
    heart_rate_bpm,
    body_temperature_c,
    respiratory_rate_bpm,
    motion_activity,
    posture,
    ambient_temperature_c: Number(jitter(24, 1).toFixed(1)),
    humidity_percent: Number(jitter(55, 3).toFixed(1)),
  };
}

async function postPayload(
  config: SimulatorConfig,
  payload: TelemetryPayload,
): Promise<{ status: number; body: unknown }> {
  const res = await fetch(config.functionUrl, {
    method: "POST",
    headers: { "content-type": "application/json", "x-device-key": config.deviceKey },
    body: JSON.stringify(payload),
  });
  const body = await res.json().catch(() => null);
  return { status: res.status, body };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const config = readConfig();
  console.log(
    `FurFeel simulator: device=${config.deviceCode} interval=${config.intervalMs}ms ` +
      `sweep=${config.sweep}${config.sweep ? ` (${config.sweepTicks} ticks to high)` : ""}` +
      `${config.maxTicks !== null ? ` maxTicks=${config.maxTicks}` : ""}`,
  );

  let stopping = false;
  process.on("SIGINT", () => {
    console.log("\nStopping after current tick...");
    stopping = true;
  });

  let tick = 0;
  while (!stopping && (config.maxTicks === null || tick < config.maxTicks)) {
    const payload = buildPayload(config, tick);
    try {
      const { status, body } = await postPayload(config, payload);
      console.log(
        `[tick ${tick}] hr=${payload.heart_rate_bpm} rr=${payload.respiratory_rate_bpm} ` +
          `temp=${payload.body_temperature_c} motion=${payload.motion_activity} posture=${payload.posture} ` +
          `-> ${status} ${JSON.stringify(body)}`,
      );
    } catch (err) {
      console.error(`[tick ${tick}] request failed:`, err);
    }
    tick += 1;
    if (stopping || (config.maxTicks !== null && tick >= config.maxTicks)) break;
    await sleep(config.intervalMs);
  }

  console.log(`Simulator finished after ${tick} tick(s).`);
}

main();
