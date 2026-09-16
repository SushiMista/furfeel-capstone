import type { SupabaseClient } from "@supabase/supabase-js";

export interface SeedBiotelemetryOptions {
  dogId: string;
  deviceId: string;
  count?: number;
  baselineHr?: number;
  baselineRr?: number;
}

/**
 * Seeds realistic initial placeholder biotelemetry data and ML stress classifications
 * for a newly admitted canine or freshly paired collar.
 *
 * This ensures that dogs created during demos, testing, or clinical intake
 * immediately show live, realistic time-series graphs and active vital cards
 * on the Monitoring Board and Detail screens without needing a physical ESP32 streaming.
 */
export async function seedInitialBiotelemetry(
  client: SupabaseClient,
  options: SeedBiotelemetryOptions,
): Promise<void> {
  const {
    dogId,
    deviceId,
    count = 6,
    baselineHr = 85,
    baselineRr = 20,
  } = options;

  // 1. Try atomic Postgres RPC first
  try {
    const { error: rpcError } = await client.rpc("seed_dog_biotelemetry", {
      p_dog_id: dogId,
      p_device_id: deviceId,
      p_count: count,
      p_baseline_hr: baselineHr,
      p_baseline_rr: baselineRr,
    });

    if (!rpcError) {
      return;
    }
  } catch {
    // Fall back to client-side batch insert below
  }

  // 2. Client-Side Fallback Insertion (if RPC not yet migrated in remote DB)
  try {
    const now = Date.now();
    for (let i = 1; i <= count; i++) {
      const minutesAgo = (count - i) * 5;
      const capturedAt = new Date(now - minutesAgo * 60 * 1000).toISOString();

      // Realistic minor variations
      const hrVariance = Math.floor(Math.random() * 9) - 4; // -4 to +4
      const rrVariance = Math.floor(Math.random() * 5) - 2; // -2 to +2
      const motion = Number((0.12 + Math.random() * 0.15).toFixed(3));
      const posture = motion < 0.18 ? "lying" : "sitting";
      const ambientTemp = Number((24.5 + (Math.random() * 1.0 - 0.5)).toFixed(1));
      const humidity = Number((52.0 + (Math.random() * 3.0 - 1.5)).toFixed(1));

      // Insert Telemetry Reading
      const { data: readingData, error: readingErr } = await client
        .from("telemetry_readings")
        .insert({
          device_id: deviceId,
          dog_id: dogId,
          captured_at: capturedAt,
          received_at: capturedAt,
          heart_rate_bpm: baselineHr + hrVariance,
          respiratory_rate_bpm: baselineRr + rrVariance,
          motion_activity: motion,
          posture,
          ambient_temperature_c: ambientTemp,
          humidity_percent: humidity,
          is_valid: true,
          raw_payload: {
            simulated: true,
            baseline: true,
            point_index: i,
          },
        })
        .select("id")
        .single();

      if (!readingErr && readingData?.id) {
        const score = Number((0.1 + Math.random() * 0.12).toFixed(2));

        // Insert Matching Stress Classification
        await client.from("stress_classifications").insert({
          dog_id: dogId,
          telemetry_reading_id: readingData.id,
          stress_level: "calm",
          score,
          confidence: 0.95,
          reasons: [
            "Normal resting heart rate within baseline",
            "Low motion activity",
            "Resting posture detected",
          ],
          model_version: "rule-v1",
          created_at: capturedAt,
        });
      }
    }

    // Update device battery and last_seen_at
    await client
      .from("devices")
      .update({
        battery_percent: 95,
        last_seen_at: new Date().toISOString(),
      })
      .eq("id", deviceId);
  } catch (err) {
    console.warn("Could not seed initial telemetry placeholder:", err);
  }
}
