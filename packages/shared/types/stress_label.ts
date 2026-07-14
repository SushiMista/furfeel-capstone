import type { StressLevel } from "./stress.ts";

/** stress_labels row shape (docs/09 Database Schema). Vet-confirmed ground truth
 * written by the dashboard's confirm/override control — the labeled data that will
 * train the future Random Forest. */
export interface StressLabel {
  id: string;
  dog_id: string;
  classification_id: string | null;
  telemetry_reading_id: string | null;
  vet_user_id: string;
  confirmed_level: StressLevel;
  agreed_with_model: boolean | null;
  note: string | null;
  created_at: string;
}
