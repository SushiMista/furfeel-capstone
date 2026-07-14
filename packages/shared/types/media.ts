export type MediaType = "video" | "image";

/** media_submissions row shape (docs/09 Database Schema). Supplementary owner
 * context for vet review — NEVER a classifier input (ADR-010). */
export interface MediaSubmission {
  id: string;
  dog_id: string;
  submitted_by_user_id: string;
  storage_path: string;
  media_type: MediaType;
  note: string | null;
  reviewed_by_user_id: string | null;
  reviewed_at: string | null;
  review_note: string | null;
  created_at: string;
}
