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
 * when absent or when an individual field is null (docs/08). threshold_ columns
 * override the score->level cut points the same way; NULL means "use
 * packages/shared/classifier_config.json.level_thresholds". The hr_ratio_,
 * rr_ratio_, body_temp_, motion_, ambient_heat_c, and humidity_heat_pct columns
 * are one level finer: they override where each individual SIGNAL starts
 * scoring (classifier_config.json.scoring_rules tier floors), independent of
 * the threshold_ score-level cutoffs above. */
export interface DogBaselines {
  id: string;
  dog_id: string;
  resting_heart_rate_bpm: number | null;
  resting_respiratory_rate_bpm: number | null;
  normal_body_temperature_c: number | null;
  threshold_mild_min: number | null;
  threshold_moderate_min: number | null;
  threshold_high_min: number | null;
  hr_ratio_elevated_min: number | null;
  hr_ratio_moderate_min: number | null;
  hr_ratio_high_min: number | null;
  rr_ratio_elevated_min: number | null;
  rr_ratio_high_min: number | null;
  body_temp_elevated_c: number | null;
  body_temp_high_c: number | null;
  motion_elevated_min: number | null;
  motion_high_min: number | null;
  ambient_heat_c: number | null;
  humidity_heat_pct: number | null;
  updated_at: string;
}
