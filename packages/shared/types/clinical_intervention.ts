export type ClinicalInterventionType =
  | "medication"
  | "feeding"
  | "walk"
  | "procedure"
  | "vet_exam"
  | "other";

export interface ClinicalIntervention {
  id: string;
  dog_id: string;
  clinic_id: string | null;
  intervention_type: ClinicalInterventionType;
  title: string;
  notes: string | null;
  dosage: string | null;
  administered_by: string | null;
  administered_by_name?: string | null;
  created_at: string;
}
