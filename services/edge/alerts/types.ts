export type AlertType = "moderate_stress" | "high_stress" | "low_battery";

export interface AlertDecision {
  type: AlertType;
  severity: "warning" | "critical";
  message: string;
}
