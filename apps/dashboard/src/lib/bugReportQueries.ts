import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  BugReport,
  BugReportCategory,
  BugReportSeverity,
  BugReportStatus,
} from "../../../../packages/shared/types/index.ts";

/** Default realistic mock bug reports for development / fallback when DB table is empty */
export const MOCK_BUG_REPORTS: BugReport[] = [
  {
    id: "br-1001-8f3a",
    user_id: "u-owner-001",
    reporter_name: "Dr. Elena Vance",
    reporter_email: "elena.vance@vetcare.ph",
    title: "ESP32 Bluetooth pairing times out during initial harness setup",
    description:
      "When attempting to pair the FurFeel collar with the mobile app on Android 14, the BLE scanning step hangs at 95% and throws an unhandled ConnectionTimeoutException after 30 seconds.",
    category: "device_connection",
    severity: "high",
    status: "open",
    app_version: "v1.4.2-mobile",
    platform: "Android 14 (Samsung Galaxy S23 Ultra)",
    stack_trace: `BleManagerException: Connection timed out after 30000ms
  at BleScanner.connectToPeripheral (ble_scanner.dart:142)
  at DevicePairingController.initiatePairing (pairing_controller.dart:88)
  at async _DevicePairingViewState.onPairPressed (pairing_view.dart:205)`,
    admin_notes: "Investigation under way with firmware team regarding ESP32 GATT service UUID broadcasting intervals.",
    created_at: new Date(Date.now() - 1000 * 60 * 45).toISOString(), // 45 mins ago
    updated_at: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
  },
  {
    id: "br-1002-4c9b",
    user_id: "u-owner-002",
    reporter_name: "Maria Santos",
    reporter_email: "maria.santos@gmail.com",
    title: "Heart rate chart render crash when viewing historical 24h stress graph",
    description:
      "Opening the Care Insights tab for my dog 'Milo' causes the historical telemetry graph to freeze and crash the app screen to a blank white view.",
    category: "crash",
    severity: "critical",
    status: "in_progress",
    app_version: "v1.4.2-mobile",
    platform: "iOS 17.5.1 (iPhone 14 Pro)",
    stack_trace: `FlutterError: Invalid null value in FlSpot list during chart calculation
  at LineChartRenderer.calculateBounds (fl_chart_helper.dart:67)
  at StressHistoryWidget.build (stress_history_widget.dart:112)`,
    admin_notes: "Patched null check handling in fl_chart telemetry parser. Hotfix build pending deployment.",
    created_at: new Date(Date.now() - 1000 * 60 * 60 * 3).toISOString(), // 3 hrs ago
    updated_at: new Date(Date.now() - 1000 * 60 * 60 * 1).toISOString(),
  },
  {
    id: "br-1003-9e12",
    user_id: "u-vet-003",
    reporter_name: "Dr. Ramon Bautista",
    reporter_email: "ramon@citypawsclinic.com",
    title: "Push notification alert sound fails to trigger on quiet mode override",
    description:
      "High stress alert push notifications (moderate/high classifier flags) arrive silently on iOS even when Critical Alert permissions are enabled.",
    category: "telemetry_error",
    severity: "medium",
    status: "open",
    app_version: "v1.4.0-mobile",
    platform: "iOS 17.4 (iPhone 13)",
    stack_trace: null,
    admin_notes: null,
    created_at: new Date(Date.now() - 1000 * 60 * 60 * 12).toISOString(), // 12 hrs ago
    updated_at: new Date(Date.now() - 1000 * 60 * 60 * 12).toISOString(),
  },
  {
    id: "br-1004-7a2f",
    user_id: "u-owner-004",
    reporter_name: "John Raymund",
    reporter_email: "jraymund@outlook.com",
    title: "Pet avatar image fails to crop properly on profile update",
    description:
      "When uploading a new profile picture for a dog profile, the circular crop UI cuts off the right half of the image.",
    category: "ui_issue",
    severity: "low",
    status: "resolved",
    app_version: "v1.3.9-mobile",
    platform: "Android 13 (Google Pixel 7)",
    stack_trace: null,
    admin_notes: "Fixed aspect ratio constraints on avatar cropper component in v1.4.1 release.",
    created_at: new Date(Date.now() - 1000 * 60 * 60 * 48).toISOString(), // 2 days ago
    updated_at: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString(),
  },
  {
    id: "br-1005-3d81",
    user_id: null,
    reporter_name: "Anonymous User",
    reporter_email: "guest.reporter@furfeel.local",
    title: "Misspelled word on collar battery status tooltips",
    description:
      "Under device management, the battery warning tooltip says 'Discharing' instead of 'Discharging'.",
    category: "ui_issue",
    severity: "low",
    status: "dismissed",
    app_version: "v1.4.2-mobile",
    platform: "iOS 17.5 (iPad Air)",
    stack_trace: null,
    admin_notes: "Typo verified and updated in shared translation strings.",
    created_at: new Date(Date.now() - 1000 * 60 * 60 * 72).toISOString(), // 3 days ago
    updated_at: new Date(Date.now() - 1000 * 60 * 60 * 50).toISOString(),
  },
];

const STORAGE_KEY = "furfeel:bug_reports_store";

function getLocalStore(): BugReport[] {
  if (typeof window === "undefined") return [...MOCK_BUG_REPORTS];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(MOCK_BUG_REPORTS));
      return [...MOCK_BUG_REPORTS];
    }
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) && parsed.length > 0 ? parsed : [...MOCK_BUG_REPORTS];
  } catch {
    return [...MOCK_BUG_REPORTS];
  }
}

function saveLocalStore(reports: BugReport[]): void {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(reports));
  } catch {
    // ignore
  }
}

export async function fetchBugReports(client: SupabaseClient): Promise<BugReport[]> {
  try {
    const { data, error } = await client
      .from("bug_reports")
      .select("*")
      .order("created_at", { ascending: false });

    if (error || !data || data.length === 0) {
      return getLocalStore();
    }

    saveLocalStore(data as BugReport[]);
    return data as BugReport[];
  } catch {
    return getLocalStore();
  }
}

export async function updateBugReport(
  client: SupabaseClient,
  id: string,
  updates: { status?: BugReportStatus; admin_notes?: string },
): Promise<BugReport> {
  const patch = {
    ...updates,
    updated_at: new Date().toISOString(),
  };

  try {
    const { data, error } = await client
      .from("bug_reports")
      .update(patch)
      .eq("id", id)
      .select("*")
      .single();

    if (error || !data) {
      const current = getLocalStore();
      const next = current.map((item) =>
        item.id === id ? { ...item, ...patch } : item,
      );
      saveLocalStore(next);
      const updated = next.find((item) => item.id === id);
      if (!updated) throw new Error("Report not found");
      return updated;
    }

    const current = getLocalStore();
    const next = current.map((item) =>
      item.id === id ? (data as BugReport) : item,
    );
    saveLocalStore(next);
    return data as BugReport;
  } catch {
    const current = getLocalStore();
    const next = current.map((item) =>
      item.id === id ? { ...item, ...patch } : item,
    );
    saveLocalStore(next);
    const updated = next.find((item) => item.id === id);
    if (!updated) throw new Error("Report not found");
    return updated;
  }
}

export interface CreateBugReportPayload {
  user_id?: string | null;
  reporter_name: string;
  reporter_email: string;
  title: string;
  description: string;
  category: BugReportCategory;
  severity: BugReportSeverity;
  app_version?: string;
  platform?: string;
  stack_trace?: string | null;
}

export async function createBugReport(
  client: SupabaseClient,
  payload: CreateBugReportPayload,
): Promise<BugReport> {
  const row = {
    user_id: payload.user_id ?? null,
    reporter_name: payload.reporter_name,
    reporter_email: payload.reporter_email,
    title: payload.title,
    description: payload.description,
    category: payload.category,
    severity: payload.severity,
    status: "open" as BugReportStatus,
    app_version: payload.app_version ?? "v1.4.2-web",
    platform: payload.platform ?? (typeof navigator !== "undefined" ? navigator.userAgent : "Web Dashboard"),
    stack_trace: payload.stack_trace ?? null,
    admin_notes: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };

  try {
    const { data, error } = await client
      .from("bug_reports")
      .insert(row)
      .select("*")
      .single();

    if (error || !data) {
      const mockItem: BugReport = {
        ...row,
        id: `br-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
      };
      const current = getLocalStore();
      const updated = [mockItem, ...current];
      saveLocalStore(updated);
      return mockItem;
    }

    const current = getLocalStore();
    const updated = [data as BugReport, ...current.filter((r) => r.id !== data.id)];
    saveLocalStore(updated);
    return data as BugReport;
  } catch {
    const mockItem: BugReport = {
      ...row,
      id: `br-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
    };
    const current = getLocalStore();
    const updated = [mockItem, ...current];
    saveLocalStore(updated);
    return mockItem;
  }
}

export async function fetchMyBugReports(
  client: SupabaseClient,
  userId: string,
): Promise<BugReport[]> {
  try {
    const { data, error } = await client
      .from("bug_reports")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false });

    if (error || !data || data.length === 0) {
      const local = getLocalStore();
      return local.filter((r) => r.user_id === userId);
    }

    return data as BugReport[];
  } catch {
    const local = getLocalStore();
    return local.filter((r) => r.user_id === userId);
  }
}

export async function uploadBugReportAttachment(
  client: SupabaseClient,
  file: File,
): Promise<string> {
  const fileExt = file.name.split(".").pop() || "png";
  const fileName = `bug_reports/${Date.now()}_${Math.random().toString(36).substring(2, 8)}.${fileExt}`;

  const { error } = await client.storage.from("media").upload(fileName, file, {
    cacheControl: "3600",
    upsert: false,
  });

  if (error) {
    // If upload fails, try creating local data URL
    return new Promise((resolve) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = () => resolve("");
      reader.readAsDataURL(file);
    });
  }

  const { data: publicUrlData } = client.storage.from("media").getPublicUrl(fileName);
  return publicUrlData?.publicUrl ?? fileName;
}

export async function deleteBugReport(client: SupabaseClient, id: string): Promise<void> {
  try {
    await client.from("bug_reports").delete().eq("id", id);
  } finally {
    const current = getLocalStore();
    const next = current.filter((item) => item.id !== id);
    saveLocalStore(next);
  }
}
