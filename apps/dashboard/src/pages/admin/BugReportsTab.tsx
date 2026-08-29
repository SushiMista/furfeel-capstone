import { useState, useMemo } from "react";
import {
  AlertTriangle,
  Bug,
  CheckCircle2,
  Clock,
  ExternalLink,
  Eye,
  Filter,
  Mail,
  RefreshCw,
  Search,
  ShieldAlert,
  Smartphone,
  Trash2,
  User,
  Wrench,
} from "lucide-react";
import type {
  BugReport,
  BugReportCategory,
  BugReportSeverity,
  BugReportStatus,
} from "../../../../../packages/shared/types/index.ts";
import { supabase } from "../../lib/supabaseClient.ts";
import { recordAuditLog } from "../../lib/auditLogger.ts";
import { updateBugReport, deleteBugReport } from "../../lib/bugReportQueries.ts";
import { Kpi } from "../overview/Overview.tsx";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Dialog } from "../../components/ui/dialog.tsx";
import { Input, Label, Select } from "../../components/ui/input.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { cn } from "../../lib/cn.ts";
import { formatPhilippineTime } from "../../lib/time.ts";

interface BugReportsTabProps {
  reports: BugReport[];
  onChanged: (report: BugReport) => void;
  onDeleted: (id: string, title?: string) => void;
  onToast: (type: "success" | "error" | "info", msg: string) => void;
  onReload?: () => void;
}

const CATEGORY_LABELS: Record<BugReportCategory, { label: string; style: string }> = {
  bug: { label: "General Bug", style: "bg-blue-100 text-blue-800 border border-blue-200" },
  ui_issue: { label: "UI / UX Issue", style: "bg-purple-100 text-purple-800 border border-purple-200" },
  device_connection: { label: "BLE / Hardware Link", style: "bg-amber-100 text-amber-900 border border-amber-300 font-medium" },
  telemetry_error: { label: "Telemetry & Pipeline", style: "bg-indigo-100 text-indigo-800 border border-indigo-200" },
  crash: { label: "Application Crash", style: "bg-rose-100 text-rose-800 border border-rose-300 font-bold" },
  other: { label: "Other Feedback", style: "bg-slate-100 text-slate-700 border border-slate-200" },
};

const SEVERITY_LABELS: Record<BugReportSeverity, { label: string; style: string }> = {
  low: { label: "Low", style: "bg-slate-100 text-slate-700 border border-slate-200" },
  medium: { label: "Medium", style: "bg-sky-50 text-sky-700 border border-sky-200" },
  high: { label: "High", style: "bg-amber-50 text-amber-800 border border-amber-300 font-semibold" },
  critical: { label: "Critical", style: "bg-rose-100 text-rose-900 border border-rose-400 font-extrabold animate-pulse" },
};

const STATUS_LABELS: Record<BugReportStatus, { label: string; style: string }> = {
  open: { label: "Open Intake", style: "bg-amber-100 text-amber-800 border border-amber-300 font-bold" },
  in_progress: { label: "In Progress", style: "bg-blue-100 text-blue-800 border border-blue-300 font-semibold" },
  resolved: { label: "Resolved", style: "bg-emerald-100 text-emerald-800 border border-emerald-300 font-semibold" },
  dismissed: { label: "Dismissed", style: "bg-slate-100 text-slate-600 border border-slate-200" },
};

export function BugReportsTab({
  reports,
  onChanged,
  onDeleted,
  onToast,
  onReload,
}: BugReportsTabProps) {
  const [searchQuery, setSearchQuery] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<string>("all");
  const [severityFilter, setSeverityFilter] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");

  const [selectedReport, setSelectedReport] = useState<BugReport | null>(null);
  const [editStatus, setEditStatus] = useState<BugReportStatus>("open");
  const [editAdminNotes, setEditAdminNotes] = useState("");
  const [updating, setUpdating] = useState(false);

  const [deleteTarget, setDeleteTarget] = useState<BugReport | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Compute summary KPI metrics
  const totalCount = reports.length;
  const openCount = reports.filter((r) => r.status === "open" || r.status === "in_progress").length;
  const criticalCount = reports.filter(
    (r) => (r.severity === "critical" || r.severity === "high") && r.status !== "resolved",
  ).length;
  const resolvedCount = reports.filter((r) => r.status === "resolved").length;

  // Filtered reports list
  const filteredReports = useMemo(() => {
    return reports.filter((r) => {
      const matchesSearch =
        searchQuery.trim() === "" ||
        r.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.reporter_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.reporter_email.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.platform.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.app_version.toLowerCase().includes(searchQuery.toLowerCase());

      const matchesCategory = categoryFilter === "all" || r.category === categoryFilter;
      const matchesSeverity = severityFilter === "all" || r.severity === severityFilter;
      const matchesStatus = statusFilter === "all" || r.status === statusFilter;

      return matchesSearch && matchesCategory && matchesSeverity && matchesStatus;
    });
  }, [reports, searchQuery, categoryFilter, severityFilter, statusFilter]);

  const handleOpenInspector = (report: BugReport) => {
    setSelectedReport(report);
    setEditStatus(report.status);
    setEditAdminNotes(report.admin_notes ?? "");
  };

  const handleSaveResolution = async () => {
    if (!selectedReport) return;
    setUpdating(true);
    try {
      const updated = await updateBugReport(supabase, selectedReport.id, {
        status: editStatus,
        admin_notes: editAdminNotes,
      });

      onChanged(updated);
      setSelectedReport(updated);

      // Audit Log
      await recordAuditLog({
        actor_role: "admin",
        surface: "dashboard",
        action: "bug_report.update_status",
        target_resource: "bug_reports",
        target_id: updated.id,
        severity: editStatus === "resolved" ? "info" : "warning",
        details: {
          previous_status: selectedReport.status,
          new_status: editStatus,
          admin_notes_updated: Boolean(editAdminNotes),
          title: updated.title,
        },
      }).catch(() => {});

      onToast("success", `Bug report status updated to ${STATUS_LABELS[editStatus].label}`);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Failed to update bug report";
      onToast("error", message);
    } finally {
      setUpdating(false);
    }
  };

  const handleDeleteReport = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await deleteBugReport(supabase, deleteTarget.id);
      onDeleted(deleteTarget.id, deleteTarget.title);

      await recordAuditLog({
        actor_role: "admin",
        surface: "dashboard",
        action: "bug_report.delete",
        target_resource: "bug_reports",
        target_id: deleteTarget.id,
        severity: "warning",
        details: { title: deleteTarget.title, reporter: deleteTarget.reporter_email },
      }).catch(() => {});

      onToast("success", "Bug report deleted successfully");
      setDeleteTarget(null);
      if (selectedReport?.id === deleteTarget.id) {
        setSelectedReport(null);
      }
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : "Failed to delete bug report";
      onToast("error", message);
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div className="flex flex-col gap-6">
      {/* KPI Cards Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Kpi
          label="Total Intake Reports"
          value={String(totalCount)}
          icon={<Bug size={22} />}
          tone="default"
        />
        <Kpi
          label="Active Open Bugs"
          value={String(openCount)}
          icon={<AlertTriangle size={22} />}
          tone="attention"
          attention={openCount > 0}
        />
        <Kpi
          label="Critical / High Issues"
          value={String(criticalCount)}
          icon={<ShieldAlert size={22} />}
          tone="attention"
          attention={criticalCount > 0}
        />
        <Kpi
          label="Resolved Bugs"
          value={String(resolvedCount)}
          icon={<CheckCircle2 size={22} />}
          tone="positive"
        />
      </div>

      {/* Main Container Card */}
      <Card>
        <CardHeader className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 pb-4">
          <div>
            <CardTitle className="flex items-center gap-2 text-lg font-bold">
              <Bug className="h-5 w-5 text-brand" />
              Mobile App &amp; Technical Bug Reports
            </CardTitle>
            <CardDescription className="text-xs text-ink-muted mt-1">
              Review, triage, and resolve incoming technical issues and bug feedback submitted by mobile app owners and clinic staff.
            </CardDescription>
          </div>
          {onReload && (
            <Button variant="secondary" size="sm" onClick={onReload} className="self-start md:self-auto gap-1.5">
              <RefreshCw className="h-3.5 w-3.5" />
              Refresh Feed
            </Button>
          )}
        </CardHeader>

        <CardContent className="space-y-4">
          <div className="flex flex-col gap-5 lg:flex-row lg:items-start">
            {/* Left Division Box: Filter & Search Controls (Sticky on scroll) */}
            <div className="w-full shrink-0 flex flex-col gap-3 rounded-lg border border-hairline bg-surface-alt/40 p-3.5 lg:w-64 lg:sticky lg:top-6 self-start">
              <div className="flex items-center justify-between border-b border-hairline pb-2">
                <div className="flex items-center gap-1.5 text-xs font-bold text-ink">
                  <Filter className="h-3.5 w-3.5 text-brand" />
                  <span>Filter Reports</span>
                </div>
                {(searchQuery.trim() !== "" || statusFilter !== "all" || severityFilter !== "all" || categoryFilter !== "all") && (
                  <button
                    type="button"
                    onClick={() => {
                      setSearchQuery("");
                      setStatusFilter("all");
                      setSeverityFilter("all");
                      setCategoryFilter("all");
                    }}
                    className="text-[11px] font-semibold text-brand hover:underline"
                  >
                    Reset
                  </button>
                )}
              </div>

              {/* Search Input */}
              <div className="flex flex-col gap-1">
                <label htmlFor="bug-search" className="text-[11px] font-semibold text-ink-muted">
                  Search Query
                </label>
                <div className="relative">
                  <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-ink-muted pointer-events-none" />
                  <Input
                    id="bug-search"
                    type="text"
                    placeholder="Title, reporter, device..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="pl-8 bg-surface text-xs h-8"
                  />
                </div>
              </div>

              {/* Status Filter Dropdown */}
              <div className="flex flex-col gap-1">
                <label htmlFor="bug-status" className="text-[11px] font-semibold text-ink-muted">
                  Status
                </label>
                <Select
                  id="bug-status"
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  className="text-xs bg-surface h-8"
                >
                  <option value="all">All Statuses</option>
                  <option value="open">Open</option>
                  <option value="in_progress">In Progress</option>
                  <option value="resolved">Resolved</option>
                  <option value="dismissed">Dismissed</option>
                </Select>
              </div>

              {/* Severity Filter Dropdown */}
              <div className="flex flex-col gap-1">
                <label htmlFor="bug-severity" className="text-[11px] font-semibold text-ink-muted">
                  Severity
                </label>
                <Select
                  id="bug-severity"
                  value={severityFilter}
                  onChange={(e) => setSeverityFilter(e.target.value)}
                  className="text-xs bg-surface h-8"
                >
                  <option value="all">All Severities</option>
                  <option value="critical">Critical</option>
                  <option value="high">High</option>
                  <option value="medium">Medium</option>
                  <option value="low">Low</option>
                </Select>
              </div>

              {/* Category Filter Dropdown */}
              <div className="flex flex-col gap-1">
                <label htmlFor="bug-category" className="text-[11px] font-semibold text-ink-muted">
                  Category
                </label>
                <Select
                  id="bug-category"
                  value={categoryFilter}
                  onChange={(e) => setCategoryFilter(e.target.value)}
                  className="text-xs bg-surface h-8"
                >
                  <option value="all">All Categories</option>
                  <option value="bug">General Bug</option>
                  <option value="ui_issue">UI / UX Issue</option>
                  <option value="device_connection">BLE / Hardware Link</option>
                  <option value="telemetry_error">Telemetry Error</option>
                  <option value="crash">App Crash</option>
                  <option value="other">Other</option>
                </Select>
              </div>
            </div>

            {/* Right Main Table Division */}
            <div className="flex-1 w-full min-w-0">

          {/* Bug Reports Table */}
          {filteredReports.length === 0 ? (
            <EmptyState>
              No bug reports found matching the selected filters.
            </EmptyState>
          ) : (
            <div className="overflow-x-auto rounded-md border border-hairline">
              <Table>
                <THead>
                  <Tr>
                    <Th>Reported At</Th>
                    <Th>Reporter</Th>
                    <Th>Category</Th>
                    <Th>Title &amp; Issue Summary</Th>
                    <Th>Platform / Version</Th>
                    <Th>Severity</Th>
                    <Th>Status</Th>
                    <Th className="text-right">Actions</Th>
                  </Tr>
                </THead>
                <TBody>
                  {filteredReports.map((report) => {
                    const categoryMeta = CATEGORY_LABELS[report.category] ?? CATEGORY_LABELS.other;
                    const severityMeta = SEVERITY_LABELS[report.severity] ?? SEVERITY_LABELS.medium;
                    const statusMeta = STATUS_LABELS[report.status] ?? STATUS_LABELS.open;

                    return (
                      <Tr key={report.id} className="hover:bg-surface-alt/40 transition-colors">
                        {/* Reported Date */}
                        <Td className="whitespace-nowrap font-mono text-xs text-ink-muted">
                          {formatPhilippineTime(report.created_at)}
                        </Td>

                        {/* Reporter Info */}
                        <Td className="min-w-[160px]">
                          <div className="flex flex-col">
                            <span className="text-xs font-semibold text-ink flex items-center gap-1">
                              <User size={12} className="text-ink-muted flex-shrink-0" />
                              {report.reporter_name}
                            </span>
                            <span className="text-[11px] text-ink-muted truncate max-w-[180px]">
                              {report.reporter_email}
                            </span>
                          </div>
                        </Td>

                        {/* Category Badge */}
                        <Td className="whitespace-nowrap">
                          <span
                            className={cn(
                              "inline-flex items-center rounded-pill px-2.5 py-0.5 text-xs font-medium",
                              categoryMeta.style,
                            )}
                          >
                            {categoryMeta.label}
                          </span>
                        </Td>

                        {/* Title & Description preview */}
                        <Td className="max-w-[280px]">
                          <div className="flex flex-col gap-0.5">
                            <span className="text-xs font-semibold text-ink line-clamp-1">
                              {report.title}
                            </span>
                            <span className="text-[11px] text-ink-muted line-clamp-1">
                              {report.description}
                            </span>
                          </div>
                        </Td>

                        {/* App Version & Platform */}
                        <Td className="whitespace-nowrap">
                          <div className="flex flex-col text-[11px]">
                            <span className="font-mono font-medium text-brand">
                              {report.app_version}
                            </span>
                            <span className="text-ink-muted flex items-center gap-1">
                              <Smartphone size={10} className="flex-shrink-0" />
                              {report.platform}
                            </span>
                          </div>
                        </Td>

                        {/* Severity Badge */}
                        <Td className="whitespace-nowrap">
                          <span
                            className={cn(
                              "inline-flex items-center rounded px-2 py-0.5 text-xs uppercase tracking-wide",
                              severityMeta.style,
                            )}
                          >
                            {severityMeta.label}
                          </span>
                        </Td>

                        {/* Status Badge */}
                        <Td className="whitespace-nowrap">
                          <span
                            className={cn(
                              "inline-flex items-center gap-1.5 rounded-pill px-2.5 py-0.5 text-xs",
                              statusMeta.style,
                            )}
                          >
                            <span
                              className={cn(
                                "h-1.5 w-1.5 rounded-full",
                                report.status === "open" && "bg-amber-500 animate-pulse",
                                report.status === "in_progress" && "bg-blue-500",
                                report.status === "resolved" && "bg-emerald-500",
                                report.status === "dismissed" && "bg-slate-400",
                              )}
                            />
                            {statusMeta.label}
                          </span>
                        </Td>

                        {/* Actions */}
                        <Td className="whitespace-nowrap text-right">
                          <div className="flex items-center justify-end gap-1">
                            <Button
                              variant="secondary"
                              size="sm"
                              title="Inspect bug report details"
                              onClick={() => handleOpenInspector(report)}
                              className="h-8 px-2 text-xs gap-1"
                            >
                              <Eye className="h-3.5 w-3.5" />
                              Review
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              title="Delete report"
                              onClick={() => setDeleteTarget(report)}
                              className="h-8 w-8 p-0 text-ink-muted hover:text-high-fg"
                            >
                              <Trash2 className="h-3.5 w-3.5" />
                            </Button>
                          </div>
                        </Td>
                      </Tr>
                    );
                  })}
                </TBody>
              </Table>
            </div>
          )}
        </div>
      </div>
    </CardContent>
      </Card>

      {/* Detail Inspector & Status Management Modal */}
      {selectedReport && (
        <Dialog
          open={Boolean(selectedReport)}
          onClose={() => setSelectedReport(null)}
          title={`Bug Report Details — ${selectedReport.id}`}
        >
          <div className="space-y-4 max-h-[80vh] overflow-y-auto pr-1">
            {/* Header info bar */}
            <div className="rounded-md bg-surface-alt p-3 border border-hairline space-y-2">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span
                  className={cn(
                    "inline-flex items-center rounded-pill px-2.5 py-0.5 text-xs font-semibold",
                    CATEGORY_LABELS[selectedReport.category]?.style,
                  )}
                >
                  {CATEGORY_LABELS[selectedReport.category]?.label}
                </span>
                <span className="text-xs text-ink-muted font-mono flex items-center gap-1">
                  <Clock size={12} />
                  {formatPhilippineTime(selectedReport.created_at)}
                </span>
              </div>
              <h3 className="text-base font-bold text-ink m-0">{selectedReport.title}</h3>
            </div>

            {/* Meta details grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs bg-surface p-3 rounded-md border border-hairline">
              <div>
                <span className="font-semibold text-ink-muted block">Reporter Name &amp; Contact:</span>
                <div className="flex items-center justify-between gap-2 mt-0.5 flex-wrap">
                  <span className="font-medium text-ink flex items-center gap-1">
                    <User size={12} className="text-brand" />
                    {selectedReport.reporter_name} ({selectedReport.reporter_email})
                  </span>
                  <a
                    href={`mailto:${selectedReport.reporter_email}?subject=${encodeURIComponent(`[FurFeel Support] Ticket #${selectedReport.id.slice(0, 8)}: ${selectedReport.title}`)}&body=${encodeURIComponent(`Hi ${selectedReport.reporter_name},\n\nRegarding your ticket "${selectedReport.title}" (#${selectedReport.id.slice(0, 8)}):\n\n`)}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 rounded bg-brand-soft px-2 py-0.5 text-[11px] font-bold text-brand hover:underline"
                  >
                    <Mail size={11} /> Reply via Email
                  </a>
                </div>
              </div>

              <div>
                <span className="font-semibold text-ink-muted block">Client Build &amp; Platform:</span>
                <span className="font-mono text-ink flex items-center gap-1 mt-0.5 truncate">
                  <Smartphone size={12} className="text-brand flex-shrink-0" />
                  {selectedReport.app_version} — {selectedReport.platform}
                </span>
              </div>

              <div>
                <span className="font-semibold text-ink-muted block">Severity Level:</span>
                <span
                  className={cn(
                    "inline-flex items-center rounded px-2 py-0.5 text-xs mt-0.5",
                    SEVERITY_LABELS[selectedReport.severity]?.style,
                  )}
                >
                  {SEVERITY_LABELS[selectedReport.severity]?.label}
                </span>
              </div>

              <div>
                <span className="font-semibold text-ink-muted block">Current Status:</span>
                <span
                  className={cn(
                    "inline-flex items-center gap-1 rounded-pill px-2.5 py-0.5 text-xs mt-0.5",
                    STATUS_LABELS[selectedReport.status]?.style,
                  )}
                >
                  {STATUS_LABELS[selectedReport.status]?.label}
                </span>
              </div>
            </div>

            {/* Description */}
            <div>
              <Label className="mb-1 block text-xs font-semibold text-ink">Problem Details &amp; Diagnostics</Label>
              <div className="rounded-md border border-hairline bg-surface p-3 text-xs text-ink whitespace-pre-wrap leading-relaxed max-h-60 overflow-y-auto">
                {selectedReport.description}
              </div>
            </div>

            {/* Stack trace / Screenshot / Error Log (If present) */}
            {selectedReport.stack_trace && (
              <div>
                <Label className="mb-1 block text-xs font-semibold text-rose-700 flex items-center gap-1">
                  <ShieldAlert size={13} />
                  Attached Diagnostics / Trace Log
                </Label>
                {selectedReport.stack_trace.startsWith("http") ? (
                  <div className="rounded-md border border-hairline bg-surface p-3 flex flex-col gap-2">
                    <img
                      src={selectedReport.stack_trace}
                      alt="Bug Report Screenshot Attachment"
                      className="max-h-56 rounded object-contain border border-hairline bg-black/5"
                    />
                    <a
                      href={selectedReport.stack_trace}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xs font-semibold text-brand flex items-center gap-1 hover:underline"
                    >
                      <ExternalLink size={12} /> Open Full Resolution Image
                    </a>
                  </div>
                ) : (
                  <pre className="max-h-48 overflow-y-auto rounded-md bg-ink-subtle p-3 font-mono text-[11px] text-high-soft border border-rose-900/40">
                    {selectedReport.stack_trace}
                  </pre>
                )}
              </div>
            )}

            {/* Resolution & Status Update Controls */}
            <div className="pt-2 border-t border-hairline space-y-3">
              <h4 className="text-xs font-bold uppercase tracking-wider text-ink-muted flex items-center gap-1">
                <Wrench size={13} className="text-brand" />
                Admin Triage &amp; Resolution Notes
              </h4>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <Label htmlFor="report-status-select" className="mb-1 block text-xs font-semibold">
                    Update Report Status
                  </Label>
                  <Select
                    id="report-status-select"
                    value={editStatus}
                    onChange={(e) => setEditStatus(e.target.value as BugReportStatus)}
                    className="text-xs bg-surface"
                  >
                    <option value="open">Open Intake</option>
                    <option value="in_progress">In Progress</option>
                    <option value="resolved">Resolved</option>
                    <option value="dismissed">Dismissed</option>
                  </Select>
                </div>

                <div className="flex items-end justify-end">
                  <Button
                    variant="default"
                    size="sm"
                    disabled={updating}
                    onClick={handleSaveResolution}
                    className="w-full sm:w-auto text-xs"
                  >
                    {updating ? "Saving Update…" : "Save Status & Notes"}
                  </Button>
                </div>
              </div>

              <div>
                <Label htmlFor="admin-notes-textarea" className="mb-1 block text-xs font-semibold">
                  Admin Resolution Notes &amp; Troubleshooting Log
                </Label>
                <textarea
                  id="admin-notes-textarea"
                  rows={3}
                  value={editAdminNotes}
                  onChange={(e) => setEditAdminNotes(e.target.value)}
                  placeholder="Enter resolution details, dev ticket links, hotfix notes..."
                  className="w-full rounded-md border border-hairline bg-surface p-2.5 text-xs text-ink placeholder:text-ink-muted focus:outline-none focus:ring-2 focus:ring-brand"
                />
              </div>
            </div>

            {/* Modal Footer */}
            <div className="flex justify-between items-center pt-3 border-t border-hairline">
              <Button
                variant="destructive"
                size="sm"
                onClick={() => setDeleteTarget(selectedReport)}
                className="text-xs"
              >
                Delete Report
              </Button>
              <Button variant="secondary" size="sm" onClick={() => setSelectedReport(null)}>
                Close
              </Button>
            </div>
          </div>
        </Dialog>
      )}

      {/* Confirm Delete Dialog */}
      {deleteTarget && (
        <Dialog
          open={Boolean(deleteTarget)}
          onClose={() => setDeleteTarget(null)}
          title="Confirm Bug Report Deletion"
        >
          <p className="m-0 mb-4 text-sm text-ink-muted">
            Are you sure you want to delete the bug report <strong>&ldquo;{deleteTarget.title}&rdquo;</strong>? This action cannot be undone.
          </p>
          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={() => setDeleteTarget(null)} disabled={deleting}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDeleteReport} disabled={deleting}>
              {deleting ? "Deleting…" : "Delete Report"}
            </Button>
          </div>
        </Dialog>
      )}
    </div>
  );
}
