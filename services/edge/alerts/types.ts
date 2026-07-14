export type AlertType = "moderate_stress" | "high_stress";

export interface AlertDecision {
  type: AlertType;
  severity: "warning" | "critical";
  message: string;
}
