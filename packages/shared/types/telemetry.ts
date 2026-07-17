export type Posture = "standing" | "sitting" | "lying" | "moving" | "unknown";

/** POST /telemetry request body (docs/07 Sensor Data Pipeline, docs/10 API and Backend
 * Services). device_code and captured_at are required; every sensor field is optional
 * (missing allowed, stored null). This is the canonical shape a well-behaved producer
 * (firmware, simulator) constructs -- distinct from the intake function's own internal
 * "untrusted wire body" type, which types optional fields as unknown until validated. */
export interface TelemetryPayload {
  device_code: string;
  captured_at: string;
  heart_rate_bpm?: number;
  body_temperature_c?: number;
  respiratory_rate_bpm?: number;
  motion_activity?: number;
  posture?: Posture;
  ambient_temperature_c?: number;
  humidity_percent?: number;
  /** 0-100; device health only, never a classifier input (docs/07). */
  battery_percent?: number;
}

/** telemetry_readings row shape (docs/09 Database Schema). */
export interface TelemetryReading {
  id: string;
  device_id: string;
  dog_id: string;
  captured_at: string;
  received_at: string;
  heart_rate_bpm: number | null;
  body_temperature_c: number | null;
  respiratory_rate_bpm: number | null;
  motion_activity: number | null;
  posture: Posture;
  ambient_temperature_c: number | null;
  humidity_percent: number | null;
  battery_percent: number | null;
  is_valid: boolean;
  raw_payload: unknown;
}
