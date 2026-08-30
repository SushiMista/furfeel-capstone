export type BugReportCategory =
  | "bug"
  | "ui_issue"
  | "device_connection"
  | "telemetry_error"
  | "crash"
  | "other";

export type BugReportSeverity = "low" | "medium" | "high" | "critical";

export type BugReportStatus = "open" | "in_progress" | "resolved" | "dismissed";

/** bug_reports row shape (Admin & Mobile bug intake). */
export interface BugReport {
  id: string;
  user_id: string | null;
  reporter_name: string;
  reporter_email: string;
  title: string;
  description: string;
  category: BugReportCategory;
  severity: BugReportSeverity;
  status: BugReportStatus;
  app_version: string;
  platform: string;
  stack_trace?: string | null;
  admin_notes?: string | null;
  created_at: string;
  updated_at: string;
}
