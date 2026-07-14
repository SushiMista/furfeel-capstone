export type StressLevel = "calm" | "mild" | "moderate" | "high";

/** stress_classifications row shape (docs/09 Database Schema). */
export interface StressClassification {
  id: string;
  dog_id: string;
  telemetry_reading_id: string;
  stress_level: StressLevel;
  score: number | null;
  confidence: number | null;
  reasons: string[] | null;
  model_version: string;
  created_at: string;
}
