export type AlertSeverity = "info" | "warning" | "critical";
export type AlertStatus = "open" | "acknowledged" | "resolved";

/** alerts row shape (docs/09 Database Schema). */
export interface Alert {
  id: string;
  dog_id: string;
  classification_id: string | null;
  severity: AlertSeverity;
  type: string;
  message: string;
  status: AlertStatus;
  acknowledged_by: string | null;
  acknowledged_at: string | null;
  created_at: string;
}
