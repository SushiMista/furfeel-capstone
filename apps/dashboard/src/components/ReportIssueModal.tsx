import { useCallback, useEffect, useState, type FormEvent } from "react";
import { useLocation } from "react-router-dom";
import {
  AlertTriangle,
  Bug,
  CheckCircle2,
  Clock,
  HelpCircle,
  LifeBuoy,
  MessageSquare,
  Paperclip,
  Radio,
  RefreshCw,
  Send,
  ShieldAlert,
  Sparkles,
  UploadCloud,
  X,
} from "lucide-react";
import { supabase } from "../lib/supabaseClient.ts";
import { useAuth } from "../lib/useAuth.ts";
import { useCurrentRole } from "../lib/useCurrentRole.ts";
import {
  createBugReport,
  fetchMyBugReports,
  uploadBugReportAttachment,
  type CreateBugReportPayload,
} from "../lib/bugReportQueries.ts";
import type {
  BugReport,
  BugReportCategory,
  BugReportSeverity,
  BugReportStatus,
} from "../../../../packages/shared/types/index.ts";
import { Dialog } from "./ui/dialog.tsx";
import { Button } from "./ui/button.tsx";
import { Input, Label, Textarea } from "./ui/input.tsx";
import { EmptyState } from "./ui/empty-state.tsx";
import { cn } from "../lib/cn.ts";
import { formatPhilippineTime } from "../lib/time.ts";

interface ReportIssueModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onToast?: (type: "success" | "error" | "info", msg: string) => void;
}

const CATEGORIES: {
  id: BugReportCategory;
  label: string;
  desc: string;
  icon: typeof Bug;
  color: string;
}[] = [
  {
    id: "bug",
    label: "Software / UI Bug",
    desc: "Visual glitch, broken button, or page error",
    icon: Bug,
    color: "text-blue-600 bg-blue-50 border-blue-200",
  },
  {
    id: "device_connection",
    label: "Collar & BLE Link",
    desc: "Bluetooth pairing, disconnection, or sync issues",
    icon: Radio,
    color: "text-amber-700 bg-amber-50 border-amber-200",
  },
  {
    id: "telemetry_error",
    label: "Telemetry & Sensor Data",
    desc: "Missing readings, abnormal stress flags, or delays",
    icon: AlertTriangle,
    color: "text-indigo-600 bg-indigo-50 border-indigo-200",
  },
  {
    id: "crash",
    label: "System Crash / Freeze",
    desc: "Screen froze, white-screen, or unhandled exception",
    icon: ShieldAlert,
    color: "text-rose-600 bg-rose-50 border-rose-200",
  },
  {
    id: "other",
    label: "Feedback / Request",
    desc: "Feature idea, clinic workflow enhancement, or inquiry",
    icon: Sparkles,
    color: "text-purple-600 bg-purple-50 border-purple-200",
  },
];

const SEVERITIES: {
  id: BugReportSeverity;
  label: string;
  desc: string;
  badgeClass: string;
}[] = [
  {
    id: "low",
    label: "Low (Minor / Cosmetic)",
    desc: "Typo or visual issue not blocking work",
    badgeClass: "bg-slate-100 text-slate-700 border-slate-200",
  },
  {
    id: "medium",
    label: "Medium (Workaround Available)",
    desc: "Feature impaired but clinical duties continue",
    badgeClass: "bg-sky-100 text-sky-800 border-sky-200",
  },
  {
    id: "high",
    label: "High (Workflow Blocked)",
    desc: "Cannot monitor patient or save clinical data",
    badgeClass: "bg-amber-100 text-amber-900 border-amber-300 font-semibold",
  },
  {
    id: "critical",
    label: "Critical (Emergency / Crash)",
    desc: "System outage, data loss, or continuous crash",
    badgeClass: "bg-rose-100 text-rose-900 border-rose-400 font-bold",
  },
];

const STATUS_CONFIG: Record<
  BugReportStatus,
  { label: string; badgeClass: string; icon: typeof Clock }
> = {
  open: {
    label: "Open Intake",
    badgeClass: "bg-amber-100 text-amber-800 border-amber-300",
    icon: Clock,
  },
  in_progress: {
    label: "In Progress",
    badgeClass: "bg-blue-100 text-blue-800 border-blue-300",
    icon: RefreshCw,
  },
  resolved: {
    label: "Resolved",
    badgeClass: "bg-emerald-100 text-emerald-800 border-emerald-300",
    icon: CheckCircle2,
  },
  dismissed: {
    label: "Dismissed",
    badgeClass: "bg-slate-100 text-slate-600 border-slate-200",
    icon: HelpCircle,
  },
};

export function ReportIssueModal({ open, onOpenChange, onToast }: ReportIssueModalProps) {
  const location = useLocation();
  const { session } = useAuth();
  const { role, name, email } = useCurrentRole();

  const [activeTab, setActiveTab] = useState<"new" | "history">("new");

  // Form states
  const [category, setCategory] = useState<BugReportCategory>("bug");
  const [severity, setSeverity] = useState<BugReportSeverity>("medium");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [includeDiagnostics, setIncludeDiagnostics] = useState(true);
  const [attachmentFile, setAttachmentFile] = useState<File | null>(null);
  const [attachmentPreview, setAttachmentPreview] = useState<string | null>(null);

  const [submitting, setSubmitting] = useState(false);
  const [submittedTicketId, setSubmittedTicketId] = useState<string | null>(null);

  // History states
  const [myTickets, setMyTickets] = useState<BugReport[]>([]);
  const [loadingTickets, setLoadingTickets] = useState(false);

  const reporterName = name || session?.user.email?.split("@")[0] || "Veterinarian";
  const reporterEmail = email || session?.user.email || "";

  // Auto-captured diagnostic summary
  const currentRoute = location.pathname + location.search;
  const browserInfo = typeof navigator !== "undefined" ? navigator.userAgent : "Browser";
  const screenResolution =
    typeof window !== "undefined" ? `${window.innerWidth}x${window.innerHeight}` : "Unknown";

  const loadMyTickets = useCallback(async () => {
    if (!session?.user.id) return;
    setLoadingTickets(true);
    try {
      const tickets = await fetchMyBugReports(supabase, session.user.id);
      setMyTickets(tickets);
    } catch {
      // ignore
    } finally {
      setLoadingTickets(false);
    }
  }, [session?.user.id]);

  useEffect(() => {
    if (open && activeTab === "history") {
      loadMyTickets();
    }
  }, [open, activeTab, loadMyTickets]);

  const handleFilePick = (file: File | null) => {
    setAttachmentFile(file);
    if (file && file.type.startsWith("image/")) {
      const url = URL.createObjectURL(file);
      setAttachmentPreview(url);
    } else {
      setAttachmentPreview(null);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !description.trim()) {
      onToast?.("error", "Please provide both a ticket title and description.");
      return;
    }

    setSubmitting(true);
    try {
      let attachmentUrl = "";
      if (attachmentFile) {
        attachmentUrl = await uploadBugReportAttachment(supabase, attachmentFile);
      }

      const diagnosticsBlock = includeDiagnostics
        ? `\n\n--- Diagnostic Context ---\n` +
          `• Route: ${currentRoute}\n` +
          `• User Role: ${role ?? "staff"}\n` +
          `• Screen: ${screenResolution}\n` +
          `• Client Time: ${new Date().toISOString()}\n` +
          (attachmentUrl ? `• Attachment: ${attachmentUrl}\n` : "")
        : "";

      const payload: CreateBugReportPayload = {
        user_id: session?.user.id ?? null,
        reporter_name: reporterName,
        reporter_email: reporterEmail,
        title: title.trim(),
        description: description.trim() + diagnosticsBlock,
        category,
        severity,
        app_version: "v1.4.2-dashboard",
        platform: `Web (${browserInfo})`,
        stack_trace: attachmentUrl || null,
      };

      const created = await createBugReport(supabase, payload);

      setSubmittedTicketId(created.id);
      onToast?.("success", `Ticket ${created.id} submitted directly to platform administrators!`);

      // Reset form
      setTitle("");
      setDescription("");
      setAttachmentFile(null);
      setAttachmentPreview(null);
      loadMyTickets();
    } catch (err: any) {
      onToast?.("error", err.message || "Failed to submit report. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={() => onOpenChange(false)}
      title="Help &amp; Issue Reporting"
    >
      <p className="text-xs text-ink-muted -mt-2 mb-4">
        Communicate bugs, collar anomalies, or system feedback directly to FurFeel platform administrators.
      </p>

      {/* Top Tab Bar */}
      <div className="flex border-b border-hairline mb-4">
        <button
          type="button"
          onClick={() => {
            setActiveTab("new");
            setSubmittedTicketId(null);
          }}
          className={cn(
            "flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-bold transition-colors",
            activeTab === "new"
              ? "border-brand text-brand"
              : "border-transparent text-ink-muted hover:text-ink",
          )}
        >
          <LifeBuoy size={16} />
          <span>Report New Issue</span>
        </button>

        <button
          type="button"
          onClick={() => {
            setActiveTab("history");
            loadMyTickets();
          }}
          className={cn(
            "flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-bold transition-colors",
            activeTab === "history"
              ? "border-brand text-brand"
              : "border-transparent text-ink-muted hover:text-ink",
          )}
        >
          <MessageSquare size={16} />
          <span>My Tickets &amp; Status</span>
          {myTickets.length > 0 && (
            <span className="rounded-full bg-brand-soft px-2 py-0.5 text-xs font-semibold text-brand">
              {myTickets.length}
            </span>
          )}
        </button>
      </div>

      {activeTab === "new" ? (
        submittedTicketId ? (
          /* Submission Success State */
          <div className="p-6 text-center">
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-emerald-50 text-emerald-600 mb-4 border border-emerald-200">
              <CheckCircle2 size={32} />
            </div>
            <h3 className="text-lg font-bold text-ink mb-1">Issue Reported Successfully</h3>
            <p className="text-sm text-ink-muted max-w-md mx-auto mb-4">
              Your ticket <span className="font-mono font-bold text-brand">{submittedTicketId}</span> has been dispatched to the platform operations and engineering team.
            </p>
            <div className="flex justify-center gap-3">
              <Button
                variant="secondary"
                onClick={() => {
                  setSubmittedTicketId(null);
                }}
              >
                Submit Another Report
              </Button>
              <Button
                variant="default"
                onClick={() => {
                  setActiveTab("history");
                  loadMyTickets();
                }}
              >
                View Ticket Status
              </Button>
            </div>
          </div>
        ) : (
          /* Issue Submission Form */
          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            {/* Auto-Captured Context Pill */}
            <div className="rounded-lg border border-hairline bg-surface-alt/70 p-3 text-xs text-ink-muted flex flex-wrap items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <span className="font-semibold text-ink">Reporter:</span>
                <span>{reporterName} ({reporterEmail})</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="font-semibold text-ink">Location:</span>
                <span className="font-mono bg-surface px-1.5 py-0.5 rounded border border-hairline text-[11px] text-brand truncate max-w-[200px]">
                  {currentRoute}
                </span>
              </div>
            </div>

            {/* Category Selection */}
            <div>
              <Label className="mb-2 block text-xs font-bold uppercase tracking-wider text-ink-muted">
                1. Select Issue Category
              </Label>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
                {CATEGORIES.map((cat) => {
                  const Icon = cat.icon;
                  const isSelected = category === cat.id;
                  return (
                    <button
                      key={cat.id}
                      type="button"
                      onClick={() => setCategory(cat.id)}
                      className={cn(
                        "flex flex-col items-start gap-1 rounded-lg border p-2.5 text-left transition-all",
                        isSelected
                          ? "border-brand bg-brand-soft/60 shadow-xs ring-1 ring-brand"
                          : "border-hairline bg-surface hover:bg-surface-alt",
                      )}
                    >
                      <div className="flex items-center gap-1.5 font-bold text-xs text-ink">
                        <Icon size={14} className={isSelected ? "text-brand" : "text-ink-muted"} />
                        <span>{cat.label}</span>
                      </div>
                      <span className="text-[10px] text-ink-muted leading-tight line-clamp-2">
                        {cat.desc}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Severity Selection */}
            <div>
              <Label className="mb-2 block text-xs font-bold uppercase tracking-wider text-ink-muted">
                2. Urgency &amp; Severity
              </Label>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                {SEVERITIES.map((sev) => {
                  const isSelected = severity === sev.id;
                  return (
                    <button
                      key={sev.id}
                      type="button"
                      onClick={() => setSeverity(sev.id)}
                      className={cn(
                        "rounded-lg border p-2 text-center text-xs transition-all",
                        isSelected
                          ? "border-brand bg-brand-soft ring-1 ring-brand font-bold text-ink"
                          : "border-hairline bg-surface text-ink-muted hover:bg-surface-alt",
                      )}
                    >
                      <div className="font-semibold">{sev.label.split(" ")[0]}</div>
                      <div className="text-[10px] text-ink-muted truncate">{sev.desc}</div>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Title & Description */}
            <div className="flex flex-col gap-3">
              <div>
                <Label htmlFor="issue-title" className="text-xs font-bold">
                  Issue Summary / Title <span className="text-rose-500">*</span>
                </Label>
                <Input
                  id="issue-title"
                  placeholder="e.g. Collar BLE disconnected during stress surge on Board"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="mt-1"
                  required
                />
              </div>

              <div>
                <Label htmlFor="issue-desc" className="text-xs font-bold">
                  Details &amp; Observations <span className="text-rose-500">*</span>
                </Label>
                <Textarea
                  id="issue-desc"
                  rows={4}
                  placeholder="Please describe what happened, patient/device involved, and any steps to reproduce the error..."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="mt-1 text-xs"
                  required
                />
              </div>
            </div>

            {/* Optional Screenshot Attachment & Diagnostics */}
            <div className="flex flex-col gap-2 rounded-lg border border-hairline bg-surface-alt/40 p-3">
              <div className="flex items-center justify-between">
                <Label className="text-xs font-semibold text-ink flex items-center gap-1.5">
                  <Paperclip size={13} className="text-ink-muted" />
                  <span>Attach Screenshot or Photo (Optional)</span>
                </Label>
                {attachmentFile && (
                  <button
                    type="button"
                    onClick={() => handleFilePick(null)}
                    className="text-xs text-rose-600 hover:underline flex items-center gap-1"
                  >
                    <X size={12} /> Remove
                  </button>
                )}
              </div>

              {attachmentPreview ? (
                <div className="relative mt-1 inline-block">
                  <img
                    src={attachmentPreview}
                    alt="Attachment Preview"
                    className="h-20 rounded border border-hairline object-cover"
                  />
                  <span className="block text-[11px] text-ink-muted mt-1 truncate">
                    {attachmentFile?.name}
                  </span>
                </div>
              ) : (
                <label className="flex cursor-pointer items-center justify-center gap-2 rounded border border-dashed border-hairline bg-surface p-3 text-xs text-ink-muted transition-colors hover:border-brand/40 hover:text-brand">
                  <UploadCloud size={16} />
                  <span>Click or drag image file here (PNG, JPG)</span>
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => handleFilePick(e.target.files?.[0] ?? null)}
                  />
                </label>
              )}

              <label className="flex items-center gap-2 text-xs text-ink-muted cursor-pointer mt-1">
                <input
                  type="checkbox"
                  checked={includeDiagnostics}
                  onChange={(e) => setIncludeDiagnostics(e.target.checked)}
                  className="h-3.5 w-3.5 rounded border-hairline text-brand focus:ring-brand"
                />
                <span>Include automatic screen route, device, and browser diagnostic context</span>
              </label>
            </div>

            {/* Action Buttons */}
            <div className="flex justify-end gap-3 pt-2">
              <Button
                type="button"
                variant="secondary"
                onClick={() => onOpenChange(false)}
                disabled={submitting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                variant="default"
                disabled={submitting || !title.trim() || !description.trim()}
              >
                {submitting ? (
                  <>
                    <RefreshCw className="mr-1.5 h-4 w-4 animate-spin" /> Submitting Ticket...
                  </>
                ) : (
                  <>
                    <Send className="mr-1.5 h-4 w-4" /> Submit Report to Admin
                  </>
                )}
              </Button>
            </div>
          </form>
        )
      ) : (
        /* My Reported Tickets Tab */
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-ink-muted">
              Past tickets submitted by your account
            </span>
            <Button
              variant="secondary"
              size="sm"
              onClick={loadMyTickets}
              disabled={loadingTickets}
            >
              <RefreshCw className={cn("mr-1 h-3.5 w-3.5", loadingTickets && "animate-spin")} />
              Refresh
            </Button>
          </div>

          {loadingTickets ? (
            <div className="py-8 text-center text-xs text-ink-muted">
              Loading submitted tickets...
            </div>
          ) : myTickets.length === 0 ? (
            <EmptyState>No issues reported yet. Your dashboard is running smoothly! 🐾</EmptyState>
          ) : (
            <div className="flex flex-col gap-3 max-h-[420px] overflow-y-auto pr-1">
              {myTickets.map((ticket) => {
                const statusCfg = STATUS_CONFIG[ticket.status];
                const StatusIcon = statusCfg.icon;

                return (
                  <div
                    key={ticket.id}
                    className="rounded-lg border border-hairline bg-surface p-4 shadow-xs flex flex-col gap-2.5"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <span className="font-mono text-xs font-bold text-brand">
                            #{ticket.id.slice(0, 8)}
                          </span>
                          <span
                            className={cn(
                              "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold border",
                              statusCfg.badgeClass,
                            )}
                          >
                            <StatusIcon size={12} />
                            {statusCfg.label}
                          </span>
                          <span className="rounded bg-surface-alt px-1.5 py-0.5 text-[10px] font-semibold text-ink-muted capitalize">
                            {ticket.category.replace("_", " ")}
                          </span>
                        </div>
                        <h4 className="m-0 mt-1 text-sm font-bold text-ink">{ticket.title}</h4>
                      </div>
                      <span className="text-[11px] text-ink-muted flex-shrink-0">
                        {formatPhilippineTime(ticket.created_at)}
                      </span>
                    </div>

                    <p className="m-0 text-xs text-ink-muted whitespace-pre-wrap line-clamp-3 bg-surface-alt/40 p-2 rounded">
                      {ticket.description}
                    </p>

                    {/* Admin Response Section if present */}
                    {ticket.admin_notes && (
                      <div className="rounded-md border border-blue-200 bg-blue-50/60 p-3 text-xs">
                        <div className="flex items-center gap-1.5 font-bold text-blue-900 mb-1">
                          <MessageSquare size={13} className="text-blue-700" />
                          <span>Platform Admin Resolution Response:</span>
                        </div>
                        <p className="m-0 text-blue-950 font-medium whitespace-pre-wrap">
                          {ticket.admin_notes}
                        </p>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </Dialog>
  );
}
