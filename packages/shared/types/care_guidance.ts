import type { StressLevel } from "./stress.ts";

/** care_guidance row shape (docs/09 Database Schema). Vet-authored plain-language
 * guidance for the owner app's Care Insights — informational only, never diagnosis.
 * clinic_id null = global default. */
export interface CareGuidance {
  id: string;
  stress_level: StressLevel;
  clinic_id: string | null;
  title: string;
  body: string;
  updated_by: string | null;
  updated_at: string;
}
