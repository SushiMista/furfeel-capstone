export type UserRole = "owner" | "vet_staff" | "veterinarian" | "admin";

/** users row shape (docs/09 Database Schema). Mirrors auth.users; id = auth.uid(). */
export interface User {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  clinic_id: string | null;
  /** Path in the private `avatars` bucket (resolved via signed URL). */
  avatar_path: string | null;
  created_at: string;
}

/** user_settings row shape (docs/09) — per-user preferences, one row per user. */
export interface UserSettings {
  user_id: string;
  theme: "system" | "light" | "dark";
  temperature_unit: "c" | "f";
  notifications_enabled: boolean;
  /** "HH:MM:SS" as Postgres `time` renders it; null = no quiet hours. */
  quiet_hours_start: string | null;
  quiet_hours_end: string | null;
  updated_at: string;
}

/** clinics row shape (docs/09 Database Schema). */
export interface Clinic {
  id: string;
  name: string;
  address: string | null;
  contact_number: string | null;
  created_at: string;
}

/** push_tokens row shape — device push registration (docs/04 notifications). */
export interface PushToken {
  id: string;
  user_id: string;
  platform: "ios" | "android" | "web";
  token: string;
  created_at: string;
  updated_at: string;
}
