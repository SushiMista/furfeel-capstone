export type DogSex = "male" | "female" | "unknown";

/** dogs row shape (docs/09 Database Schema). */
export interface Dog {
  id: string;
  owner_user_id: string;
  clinic_id: string | null;
  name: string;
  breed: string | null;
  birthdate: string | null;
  sex: DogSex | null;
  weight_kg: number | null;
  notes: string | null;
  photo_path: string | null;
  created_at: string;
}

/** dog_baselines row shape. 0-or-1 per dog; classifier falls back to global defaults
 * when absent or when an individual field is null (docs/08). */
export interface DogBaselines {
  id: string;
  dog_id: string;
  resting_heart_rate_bpm: number | null;
  resting_respiratory_rate_bpm: number | null;
  normal_body_temperature_c: number | null;
  updated_at: string;
}
