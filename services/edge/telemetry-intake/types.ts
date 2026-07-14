/** Raw POST /telemetry body, per docs/07 Sensor Data Pipeline / docs/10 API and Backend Services.
 * device_code and captured_at are required; every sensor field is optional (missing allowed). */
export interface TelemetryRequestBody {
  device_code: string;
  captured_at: string;
  heart_rate_bpm?: unknown;
  body_temperature_c?: unknown;
  respiratory_rate_bpm?: unknown;
  motion_activity?: unknown;
  posture?: unknown;
  ambient_temperature_c?: unknown;
  humidity_percent?: unknown;
}
