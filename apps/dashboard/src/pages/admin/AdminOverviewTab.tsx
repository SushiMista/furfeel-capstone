import { useState, useEffect, useCallback, useMemo } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  Activity,
  ArrowRight,
  BellRing,
  Bug,
  Building2,
  CheckCircle2,
  Cpu,
  Dog as DogIcon,
  FileSearch,
  Plus,
  Radio,
  RotateCcw,
  ShieldAlert,
  ShieldCheck,
  Sparkles,
  TrendingUp,
  UserCheck,
  UserCog,
  Users as UsersIcon,
  Wifi,
  WifiOff,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { fetchAuditLogs, type AuditLogRecord } from "../../lib/auditLogger.ts";
import { UserRoleChart } from "../../components/UserRoleChart.tsx";
import { DeviceAdoptionChart } from "../../components/DeviceAdoptionChart.tsx";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Badge } from "../../components/ui/badge.tsx";
import { Button } from "../../components/ui/button.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { formatPhilippineTime } from "../../lib/time.ts";
import type {
  AdminInefficiencies,
  BugReport,
  Clinic,
  Device,
  Dog,
  User,
} from "../../../../../packages/shared/types/index.ts";

export function AdminOverviewTab({
  users,
  clinics,
  devices,
  dogs,
  bugReports,
  inefficiencies,
}: {
  users: User[];
  clinics: Clinic[];
  devices: Device[];
  dogs: Dog[];
  bugReports: BugReport[];
  inefficiencies: AdminInefficiencies;
}) {
  const navigate = useNavigate();
  const [recentLogs, setRecentLogs] = useState<AuditLogRecord[]>([]);
  const [loadingLogs, setLoadingLogs] = useState(true);

  const loadLogs = useCallback(async () => {
    try {
      const logs = await fetchAuditLogs({ limit: 6 });
      setRecentLogs(logs);
    } catch {
      // non-blocking
    } finally {
      setLoadingLogs(false);
    }
  }, []);

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  // Metric Computations
  const userStats = useMemo(() => {
    return {
      total: users.length,
      vets: users.filter((u) => u.role === "veterinarian" || u.role === "vet_staff").length,
      owners: users.filter((u) => u.role === "owner" || !u.role).length,
      admins: users.filter((u) => u.role === "admin").length,
    };
  }, [users]);

  const deviceStats = useMemo(() => {
    return {
      total: devices.length,
      active: devices.filter((d) => d.status === "active").length,
      offline: devices.filter((d) => d.status === "offline").length,
      maintenance: devices.filter((d) => d.status === "maintenance").length,
      unassigned: devices.filter((d) => !d.dog_id).length,
    };
  }, [devices]);

  const openBugsCount = useMemo(() => {
    return bugReports.filter((b) => b.status === "open" || b.status === "in_progress").length;
  }, [bugReports]);

  return (
    <div className="flex flex-col gap-6">
      {/* 6 Technical KPI Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-3.5">
        {/* Card 1: Clinics */}
        <Card className="border-hairline shadow-xs hover:border-brand/40 transition-colors">
          <CardContent className="p-4 flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-ink-muted uppercase tracking-wider">Partner Clinics</span>
              <div className="h-8 w-8 rounded-lg bg-brand-soft text-brand flex items-center justify-center">
                <Building2 size={16} />
              </div>
            </div>
            <div className="flex items-baseline gap-2">
              <span className="text-2xl font-black text-ink">{clinics.length}</span>
              <span className="text-[11px] font-semibold text-calm-fg">Active Facilities</span>
            </div>
          </CardContent>
        </Card>

        {/* Card 2: User Accounts */}
        <Card className="border-hairline shadow-xs hover:border-brand/40 transition-colors">
          <CardContent className="p-4 flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-ink-muted uppercase tracking-wider">Total Users</span>
              <div className="h-8 w-8 rounded-lg bg-brand-soft text-brand flex items-center justify-center">
                <UsersIcon size={16} />
              </div>
            </div>
            <div className="flex items-baseline gap-2">
              <span className="text-2xl font-black text-ink">{userStats.total}</span>
              <span className="text-[11px] text-ink-muted">
                {userStats.vets} Vets · {userStats.owners} Owners
              </span>
            </div>
          </CardContent>
        </Card>

        {/* Card 3: Hardware Collars */}
        <Card className="border-hairline shadow-xs hover:border-brand/40 transition-colors">
          <CardContent className="p-4 flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-ink-muted uppercase tracking-wider">Hardware Fleet</span>
              <div className="h-8 w-8 rounded-lg bg-brand-soft text-brand flex items-center justify-center">
                <Cpu size={16} />
              </div>
            </div>
            <div className="flex items-baseline gap-2">
              <span className="text-2xl font-black text-ink">{deviceStats.total}</span>
              <span className="text-[11px] text-calm-fg">{deviceStats.active} Active</span>
            </div>
          </CardContent>
        </Card>

        {/* Card 4: Patient Registry */}
        <Card className="border-hairline shadow-xs hover:border-brand/40 transition-colors">
          <CardContent className="p-4 flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-ink-muted uppercase tracking-wider">Registered Canines</span>
              <div className="h-8 w-8 rounded-lg bg-brand-soft text-brand flex items-center justify-center">
                <DogIcon size={16} />
              </div>
            </div>
            <div className="flex items-baseline gap-2">
              <span className="text-2xl font-black text-ink">{dogs.length}</span>
              <span className="text-[11px] text-ink-muted">Across Clinics</span>
            </div>
          </CardContent>
        </Card>

        {/* Card 5: Bug Reports */}
        <Card className="border-hairline shadow-xs hover:border-brand/40 transition-colors">
          <CardContent className="p-4 flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-ink-muted uppercase tracking-wider">Open Bug Reports</span>
              <div className={`h-8 w-8 rounded-lg flex items-center justify-center ${openBugsCount > 0 ? "bg-amber-500/10 text-amber-600" : "bg-calm-soft text-calm-fg"}`}>
                <Bug size={16} />
              </div>
            </div>
            <div className="flex items-baseline gap-2">
              <span className="text-2xl font-black text-ink">{openBugsCount}</span>
              <span className="text-[11px] text-ink-muted">Triage Queue</span>
            </div>
          </CardContent>
        </Card>

        {/* Card 6: System Health */}
        <Card className="border-hairline shadow-xs hover:border-brand/40 transition-colors">
          <CardContent className="p-4 flex flex-col gap-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-ink-muted uppercase tracking-wider">Platform Status</span>
              <div className="h-8 w-8 rounded-lg bg-calm-soft text-calm-fg flex items-center justify-center">
                <ShieldCheck size={16} />
              </div>
            </div>
            <div className="flex items-baseline gap-2">
              <span className="text-lg font-black text-calm-fg">100% Up</span>
              <span className="text-[11px] text-ink-muted">All Healthy</span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Quick Action Station */}
      <Card className="border-hairline shadow-xs bg-surface">
        <CardHeader className="pb-3 border-b border-hairline/60">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Sparkles size={16} className="text-brand" />
              <CardTitle className="text-base font-bold text-ink">Technical Quick Actions</CardTitle>
            </div>
            <span className="text-xs text-ink-muted font-medium">Administrative Shortcuts</span>
          </div>
        </CardHeader>
        <CardContent className="pt-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          <Link
            to="/admin/users"
            className="flex items-center justify-between p-3.5 rounded-xl border border-hairline bg-surface-alt/40 hover:bg-brand-soft/30 hover:border-brand/30 transition-all group"
          >
            <div className="flex items-center gap-3">
              <div className="h-9 w-9 rounded-lg bg-brand text-white flex items-center justify-center shadow-xs">
                <UserCog size={17} />
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-bold text-ink group-hover:text-brand">Manage User Accounts</span>
                <span className="text-[11px] text-ink-muted">Roles & Permissions</span>
              </div>
            </div>
            <ArrowRight size={14} className="text-ink-muted group-hover:text-brand group-hover:translate-x-1 transition-all" />
          </Link>

          <Link
            to="/admin/clinics"
            className="flex items-center justify-between p-3.5 rounded-xl border border-hairline bg-surface-alt/40 hover:bg-brand-soft/30 hover:border-brand/30 transition-all group"
          >
            <div className="flex items-center gap-3">
              <div className="h-9 w-9 rounded-lg bg-brand text-white flex items-center justify-center shadow-xs">
                <Building2 size={17} />
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-bold text-ink group-hover:text-brand">Onboard Clinics</span>
                <span className="text-[11px] text-ink-muted">Partner Facilities</span>
              </div>
            </div>
            <ArrowRight size={14} className="text-ink-muted group-hover:text-brand group-hover:translate-x-1 transition-all" />
          </Link>

          <Link
            to="/admin/devices"
            className="flex items-center justify-between p-3.5 rounded-xl border border-hairline bg-surface-alt/40 hover:bg-brand-soft/30 hover:border-brand/30 transition-all group"
          >
            <div className="flex items-center gap-3">
              <div className="h-9 w-9 rounded-lg bg-brand text-white flex items-center justify-center shadow-xs">
                <Cpu size={17} />
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-bold text-ink group-hover:text-brand">Hardware Inventory</span>
                <span className="text-[11px] text-ink-muted">Collar Telemetry Fleet</span>
              </div>
            </div>
            <ArrowRight size={14} className="text-ink-muted group-hover:text-brand group-hover:translate-x-1 transition-all" />
          </Link>

          <Link
            to="/admin/health"
            className="flex items-center justify-between p-3.5 rounded-xl border border-hairline bg-surface-alt/40 hover:bg-brand-soft/30 hover:border-brand/30 transition-all group"
          >
            <div className="flex items-center gap-3">
              <div className="h-9 w-9 rounded-lg bg-calm-fg text-white flex items-center justify-center shadow-xs">
                <Activity size={17} />
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-bold text-ink group-hover:text-calm-fg">System Health</span>
                <span className="text-[11px] text-ink-muted">Server & Latency</span>
              </div>
            </div>
            <ArrowRight size={14} className="text-ink-muted group-hover:text-calm-fg group-hover:translate-x-1 transition-all" />
          </Link>
        </CardContent>
      </Card>

      {/* Distribution Charts & Recent Audit Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* User Roles Chart */}
        <Card className="border-hairline shadow-xs">
          <CardHeader className="pb-2">
            <CardTitle className="text-base font-bold text-ink">User Role Distribution</CardTitle>
            <CardDescription>Breakdown of platform participants across clinical and owner roles.</CardDescription>
          </CardHeader>
          <CardContent className="pt-2">
            <UserRoleChart users={users} />
          </CardContent>
        </Card>

        {/* Live Security Audit Trail */}
        <Card className="border-hairline shadow-xs">
          <CardHeader className="pb-3 border-b border-hairline/60">
            <div className="flex items-center justify-between">
              <div>
                <CardTitle className="text-base font-bold text-ink">Recent Security Audit Trail</CardTitle>
                <CardDescription>Immutable log of administrative & critical platform actions.</CardDescription>
              </div>
              <Link to="/admin/audit" className="text-xs font-bold text-brand hover:underline">
                View All Logs →
              </Link>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            {loadingLogs ? (
              <div className="p-4">
                <CardSkeleton lines={4} />
              </div>
            ) : recentLogs.length === 0 ? (
              <div className="p-6 text-center text-xs text-ink-muted">No audit events recorded yet.</div>
            ) : (
              <div className="divide-y divide-hairline">
                {recentLogs.map((log) => (
                  <div key={log.id} className="p-3.5 flex items-center justify-between hover:bg-surface-alt/30 transition-colors">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-surface-alt text-ink font-mono text-xs shrink-0 font-bold border border-hairline">
                        <FileSearch size={14} />
                      </div>
                      <div className="flex flex-col min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="font-mono text-xs font-bold text-ink truncate">{log.action}</span>
                          <span
                            className={`rounded px-1.5 py-0.2 text-[9px] font-black uppercase ${
                              log.severity === "critical"
                                ? "bg-red-100 text-red-800"
                                : log.severity === "warning"
                                  ? "bg-amber-100 text-amber-800"
                                  : "bg-slate-100 text-slate-700"
                            }`}
                          >
                            {log.severity}
                          </span>
                        </div>
                        <span className="text-[11px] text-ink-muted truncate">
                          by {log.actor_email} ({log.actor_role}) on {log.target_resource}
                        </span>
                      </div>
                    </div>
                    <span className="text-[10px] text-ink-muted shrink-0 pl-2">
                      {formatPhilippineTime(log.created_at)}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
