import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";
import { Link, Navigate, useParams, useSearchParams } from "react-router-dom";
import {
  Activity,
  ArrowRight,
  Bell,
  Building2,
  CheckCheck,
  Cpu,
  Dog as DogIcon,
  Download,
  Eye,
  Pencil,
  Plus,
  RefreshCw,
  RotateCcw,
  Search,
  ShieldAlert,
  Trash2,
  Users as UsersIcon,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  fetchAuditLogs,
  type AuditLogRecord,
} from "../../lib/auditLogger.ts";
import {
  bulkDeleteClinics,
  bulkDeleteDevices,
  bulkDeleteDogs,
  bulkDeleteUserAccounts,
  calculateAdminInefficiencies,
  createClinic,
  createDog,
  createUserAccount,
  deleteClinic,
  deleteDevice,
  deleteDog,
  deleteUserAccount,
  fetchAllDevices,
  fetchAllDogs,
  fetchAllUsers,
  fetchClinics,
  fetchSystemHealth,
  reactivateUserAccount,
  registerDevice,
  updateClinic,
  updateDevice,
  updateDog,
  updateDogClinic,
  updateUserRoleClinic,
  type AdminInefficiencies,
  type SystemHealth,
} from "../../lib/adminQueries.ts";
import { Kpi } from "../overview/Overview.tsx";
import { useCurrentRole } from "../../lib/useCurrentRole.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Dialog } from "../../components/ui/dialog.tsx";
import { Input, Label, Select } from "../../components/ui/input.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { cn } from "../../lib/cn.ts";
import { useToast } from "../../components/ui/toast.tsx";
import {
  acknowledgeAlert,
  fetchAlertsQueue,
  getMediaSignedUrl,
  uploadDogPhoto,
} from "../../lib/queries.ts";
import { AlertCard } from "../../components/AlertCard.tsx";
import { DeviceAdoptionChart } from "../../components/DeviceAdoptionChart.tsx";
import { formatPhilippineTime } from "../../lib/time.ts";
import { dogTint } from "../../lib/dogTint.ts";
import { BugReportsTab } from "./BugReportsTab.tsx";
import { fetchBugReports } from "../../lib/bugReportQueries.ts";
import type {
  Alert,
  BugReport,
  Clinic,
  Device,
  DeviceStatus,
  Dog,
  DogSex,
  User,
  UserRole,
} from "../../../../../packages/shared/types/index.ts";

const DEVICE_STATUSES: DeviceStatus[] = ["active", "inactive", "offline", "maintenance"];
type Tab = "users" | "clinics" | "devices" | "dogs" | "dog-clinic" | "bugs" | "audit" | "health";
const TABS: Tab[] = ["users", "clinics", "devices", "dogs", "dog-clinic", "bugs", "audit", "health"];

/** Shared destructive-action confirmation (docs/19 dialog primitive). */
function ConfirmDeleteDialog({
  open,
  title,
  description,
  busy,
  onConfirm,
  onClose,
}: {
  open: boolean;
  title: string;
  description: string;
  busy: boolean;
  onConfirm: () => void;
  onClose: () => void;
}) {
  return (
    <Dialog open={open} onClose={onClose} title={title}>
      <p className="m-0 mb-4 text-sm text-ink-muted leading-relaxed">{description}</p>
      <div className="flex justify-end gap-2">
        <Button variant="secondary" onClick={onClose} disabled={busy}>
          Cancel
        </Button>
        <Button variant="destructive" onClick={onConfirm} disabled={busy}>
          {busy ? "Deleting…" : "Delete"}
        </Button>
      </div>
    </Dialog>
  );
}

/** Admin (docs/05 §4): Super-Admin Console with full CRUD, Bulk Operations, Inefficiencies & Security Suite. */
export function Admin() {
  const { tab: tabParam } = useParams<{ tab: string }>();
  const { role, loading: roleLoading } = useCurrentRole();
  const { session } = useAuth();
  const toast = useToast();
  const [users, setUsers] = useState<User[]>([]);
  const [clinics, setClinics] = useState<Clinic[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [bugReports, setBugReports] = useState<BugReport[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [userRows, clinicRows, deviceRows, dogRows, bugRows] = await Promise.all([
        fetchAllUsers(supabase),
        fetchClinics(supabase),
        fetchAllDevices(supabase),
        fetchAllDogs(supabase),
        fetchBugReports(supabase),
      ]);
      setUsers(userRows);
      setClinics(clinicRows);
      setDevices(deviceRows);
      setDogs(dogRows);
      setBugReports(bugRows);
      setError(null);
    } catch (err) {
      setError(friendlyError(err, "load admin data"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const clinicNames = useMemo(() => new Map(clinics.map((c) => [c.id, c.name])), [clinics]);
  const dogNames = useMemo(() => new Map(dogs.map((d) => [d.id, d.name])), [dogs]);

  const inefficiencies = useMemo(
    () => calculateAdminInefficiencies(devices, dogs, users),
    [devices, dogs, users],
  );

  if (roleLoading || loading) return <CardSkeleton lines={6} />;
  if (role !== "admin")
    return (
      <EmptyState>
        This area is for clinic administrators. If you should have access, ask an admin to
        update your role.
      </EmptyState>
    );
  if (error)
    return (
      <p role="alert" className="rounded-md bg-[#DC2626] px-4 py-3 text-sm font-semibold text-white shadow-sm">
        {error}
      </p>
    );

  if (!tabParam || !TABS.includes(tabParam as Tab)) return <Navigate to="/admin/users" replace />;
  const tab = tabParam as Tab;

  const displayTabTitle =
    tab === "bugs"
      ? "Bug Reports"
      : tab === "dogs" || tab === "dog-clinic"
        ? "Dog Management"
        : tab === "users"
          ? "User Accounts"
          : tab === "clinics"
            ? "Partner Clinics"
            : tab === "devices"
              ? "Device Management"
              : tab === "audit"
                ? "Audit Logs"
                : "System Health";

  return (
    <div className="flex flex-col gap-6">
      {/* Top Banner: Inefficiencies & Operational Alerts */}
      <AdminInefficienciesBanner inefficiencies={inefficiencies} />

      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-hairline pb-4">
        <div>
          <h1 className="m-0 text-2xl font-extrabold capitalize text-ink tracking-tight">
            Admin — {displayTabTitle}
          </h1>
          <p className="m-0 mt-1 text-xs text-ink-muted">
            Platform governance, user credentials, partner clinics, and patient hardware fleet
          </p>
        </div>
      </div>

      {tab === "users" && (
        <UsersTab
          users={users}
          clinics={clinics}
          currentUserId={session?.user.id ?? null}
          onChanged={(u) => {
            setUsers((prev) => prev.map((x) => (x.id === u.id ? u : x)));
            toast("success", `${u.name} updated`);
          }}
          onCreated={(u) => {
            setUsers((prev) => [...prev, u].sort((a, b) => a.name.localeCompare(b.name)));
            toast("success", `${u.name} created as ${u.role}`);
          }}
          onDeleted={(id, name) => {
            setUsers((prev) => prev.filter((x) => x.id !== id));
            toast("success", `${name} deleted`);
          }}
          onBulkDeleted={(deletedIds, count) => {
            setUsers((prev) => prev.filter((x) => !deletedIds.includes(x.id)));
            toast("success", `Successfully processed ${count} user accounts`);
          }}
          onError={(m) => toast("error", m)}
        />
      )}

      {tab === "clinics" && (
        <ClinicsTab
          clinics={clinics}
          onCreated={(c) => {
            setClinics((prev) => [...prev, c].sort((a, b) => a.name.localeCompare(b.name)));
            toast("success", `${c.name} created`);
          }}
          onChanged={(c) => {
            setClinics((prev) =>
              prev.map((x) => (x.id === c.id ? c : x)).sort((a, b) => a.name.localeCompare(b.name)),
            );
            toast("success", `${c.name} updated`);
          }}
          onDeleted={(id, name) => {
            setClinics((prev) => prev.filter((x) => x.id !== id));
            toast("success", `${name} deleted`);
          }}
          onBulkDeleted={(deletedIds, count) => {
            setClinics((prev) => prev.filter((x) => !deletedIds.includes(x.id)));
            toast("success", `Deleted ${count} partner clinics`);
          }}
          onError={(m) => toast("error", m)}
        />
      )}

      {tab === "devices" && (
        <DevicesTab
          devices={devices}
          dogs={dogs}
          dogNames={dogNames}
          onChanged={(d) => setDevices((prev) => prev.map((x) => (x.id === d.id ? d : x)))}
          onRegistered={(d) => setDevices((prev) => [...prev, d])}
          onDeleted={(id) => setDevices((prev) => prev.filter((x) => x.id !== id))}
          onBulkDeleted={(deletedIds, count) => {
            setDevices((prev) => prev.filter((x) => !deletedIds.includes(x.id)));
            toast("success", `Processed ${count} devices`);
          }}
          onToast={toast}
        />
      )}

      {(tab === "dogs" || tab === "dog-clinic") && (
        <DogsTab
          dogs={dogs}
          users={users}
          clinics={clinics}
          devices={devices}
          clinicNames={clinicNames}
          onCreated={(d) => {
            setDogs((prev) => [...prev, d].sort((a, b) => a.name.localeCompare(b.name)));
            toast("success", `Dog "${d.name}" created successfully`);
          }}
          onChanged={(d) => {
            setDogs((prev) => prev.map((x) => (x.id === d.id ? d : x)));
            toast("success", `Dog "${d.name}" updated`);
          }}
          onDeleted={(id, name) => {
            setDogs((prev) => prev.filter((x) => x.id !== id));
            toast("success", `Dog "${name}" deleted`);
          }}
          onBulkDeleted={(deletedIds, count) => {
            setDogs((prev) => prev.filter((x) => !deletedIds.includes(x.id)));
            toast("success", `Deleted ${count} dogs`);
          }}
          onDeviceChanged={(dev) => {
            setDevices((prev) => prev.map((x) => (x.id === dev.id ? dev : x)));
          }}
          onToast={toast}
        />
      )}

      {tab === "bugs" && (
        <BugReportsTab
          reports={bugReports}
          onChanged={(updated) =>
            setBugReports((prev) => prev.map((x) => (x.id === updated.id ? updated : x)))
          }
          onDeleted={(id) => setBugReports((prev) => prev.filter((x) => x.id !== id))}
          onToast={toast}
          onReload={() => {
            fetchBugReports(supabase).then(setBugReports).catch(() => {});
          }}
        />
      )}

      {tab === "audit" && <AuditLogsTab />}

      {tab === "health" && (
        <HealthTab users={users} clinics={clinics} devices={devices} dogs={dogs} />
      )}
    </div>
  );
}

/** Operational Inefficiencies and Actionable Alert Banner */
function AdminInefficienciesBanner({ inefficiencies }: { inefficiencies: AdminInefficiencies }) {
  const { unassignedActiveDevices, unassignedDogs, staleDevices, inactiveUsers } = inefficiencies;

  const totalInefficiencies =
    unassignedActiveDevices.length + unassignedDogs.length + staleDevices.length + inactiveUsers.length;

  if (totalInefficiencies === 0) return null;

  return (
    <div className="rounded-xl border border-amber-200 bg-amber-50/50 p-4 shadow-xs">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-amber-200/60 pb-3">
        <div className="flex items-center gap-2">
          <ShieldAlert className="h-5 w-5 text-amber-600 shrink-0" />
          <h3 className="m-0 text-sm font-bold text-amber-950">
            Operational Inefficiencies Detected ({totalInefficiencies})
          </h3>
        </div>
        <span className="text-[11px] font-semibold text-amber-800">
          Proactive clinic fleet triage
        </span>
      </div>

      <div className="mt-3 grid grid-cols-1 gap-2.5 sm:grid-cols-2 lg:grid-cols-4">
        {/* Unassigned Active Devices */}
        <Link
          to="/admin/devices"
          className="flex items-center justify-between rounded-lg border border-amber-200/80 bg-surface p-3 transition-colors hover:bg-amber-100/40"
        >
          <div className="flex flex-col min-w-0">
            <span className="text-xs font-bold text-ink truncate">Unpaired Active Devices</span>
            <span className="text-[11px] text-ink-muted">Online but no patient</span>
          </div>
          <span
            className={cn(
              "rounded-full px-2 py-0.5 text-xs font-extrabold",
              unassignedActiveDevices.length > 0
                ? "bg-[#E65100] text-white"
                : "bg-surface-alt text-ink-muted",
            )}
          >
            {unassignedActiveDevices.length}
          </span>
        </Link>

        {/* Unassigned Dogs */}
        <Link
          to="/admin/dogs"
          className="flex items-center justify-between rounded-lg border border-amber-200/80 bg-surface p-3 transition-colors hover:bg-amber-100/40"
        >
          <div className="flex flex-col min-w-0">
            <span className="text-xs font-bold text-ink truncate">Unassigned Patients</span>
            <span className="text-[11px] text-ink-muted">Not linked to a clinic</span>
          </div>
          <span
            className={cn(
              "rounded-full px-2 py-0.5 text-xs font-extrabold",
              unassignedDogs.length > 0 ? "bg-amber-600 text-white" : "bg-surface-alt text-ink-muted",
            )}
          >
            {unassignedDogs.length}
          </span>
        </Link>

        {/* Stale Devices */}
        <Link
          to="/admin/devices"
          className="flex items-center justify-between rounded-lg border border-amber-200/80 bg-surface p-3 transition-colors hover:bg-amber-100/40"
        >
          <div className="flex flex-col min-w-0">
            <span className="text-xs font-bold text-ink truncate">Stale / Offline Hardware</span>
            <span className="text-[11px] text-ink-muted">Inactive &gt; 14 days</span>
          </div>
          <span
            className={cn(
              "rounded-full px-2 py-0.5 text-xs font-extrabold",
              staleDevices.length > 0 ? "bg-[#DC2626] text-white" : "bg-surface-alt text-ink-muted",
            )}
          >
            {staleDevices.length}
          </span>
        </Link>

        {/* Inactive Accounts */}
        <Link
          to="/admin/users"
          className="flex items-center justify-between rounded-lg border border-amber-200/80 bg-surface p-3 transition-colors hover:bg-amber-100/40"
        >
          <div className="flex flex-col min-w-0">
            <span className="text-xs font-bold text-ink truncate">Deactivated Accounts</span>
            <span className="text-[11px] text-ink-muted">Soft-deleted users</span>
          </div>
          <span
            className={cn(
              "rounded-full px-2 py-0.5 text-xs font-extrabold",
              inactiveUsers.length > 0 ? "bg-slate-700 text-white" : "bg-surface-alt text-ink-muted",
            )}
          >
            {inactiveUsers.length}
          </span>
        </Link>
      </div>
    </div>
  );
}

/** System Health Tab */
function HealthTab({
  users,
  clinics,
  devices,
  dogs,
}: {
  users: User[];
  clinics: Clinic[];
  devices: Device[];
  dogs: Dog[];
}) {
  const { session } = useAuth();
  const [health, setHealth] = useState<SystemHealth | null>(null);
  const [openAlertsList, setOpenAlertsList] = useState<Alert[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([fetchSystemHealth(supabase), fetchAlertsQueue(supabase, "open")])
      .then(([healthData, alertRows]) => {
        setHealth(healthData);
        setOpenAlertsList(alertRows);
      })
      .catch((err) => setError(friendlyError(err, "load system health")));
  }, []);

  const online = devices.filter((d) => d.status === "active").length;

  const dogNames = useMemo(() => new Map(dogs.map((d) => [d.id, d.name])), [dogs]);

  if (error)
    return (
      <p role="alert" className="rounded-md bg-[#DC2626] px-4 py-3 text-sm font-semibold text-white shadow-sm">
        {error}
      </p>
    );
  if (!health) return <CardSkeleton lines={6} />;

  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-6">
        <Kpi label="Total Users" value={String(users.length)} icon={<UsersIcon size={20} />} />
        <Kpi label="Clinics" value={String(clinics.length)} icon={<Building2 size={20} />} />
        <Kpi label="Patients" value={String(dogs.length)} icon={<DogIcon size={20} />} />
        <Kpi label="Active Devices" value={String(online)} icon={<Cpu size={20} />} tone={online > 0 ? "positive" : "default"} />
        <Kpi label="Telemetry / 24h" value={String(health.telemetry_last_24h)} icon={<Activity size={20} />} />
        <Kpi
          label="Open Alerts"
          value={String(health.open_alerts)}
          icon={<Bell size={20} />}
          tone={health.open_alerts > 0 ? "attention" : "default"}
          attention={health.open_alerts > 0}
        />
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Fleet Adoption &amp; Telemetry Ingestion</CardTitle>
            <CardDescription>
              Telemetry readings ingestion rate and online collar health over time.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <DeviceAdoptionChart devices={devices} dogs={dogs} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>System Activity Summary</CardTitle>
            <CardDescription>Real-time backend event stream health</CardDescription>
          </CardHeader>
          <CardContent className="flex flex-col gap-4 text-sm">
            <div className="flex items-center justify-between border-b border-hairline pb-2">
              <span className="text-ink-muted">Latest Telemetry</span>
              <span className="font-semibold text-ink">
                {health.last_telemetry_at ? formatPhilippineTime(health.last_telemetry_at) : "No readings yet"}
              </span>
            </div>
            <div className="flex items-center justify-between border-b border-hairline pb-2">
              <span className="text-ink-muted">Active Ingestion Rate</span>
              <span className="font-semibold text-ink">
                ~{Math.round(health.telemetry_last_hour / 60)} readings / min
              </span>
            </div>
            <div className="flex items-center justify-between border-b border-hairline pb-2">
              <span className="text-ink-muted">Database Health</span>
              <span className="inline-flex items-center gap-1.5 font-bold text-emerald-600">
                <CheckCheck size={16} /> Healthy (Postgres + RLS)
              </span>
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Open System Alerts Requiring Triage</CardTitle>
          <CardDescription>
            Active hardware or stress alerts requiring attention. Use the direct investigation links to view affected dogs or check offline device status.
          </CardDescription>
        </CardHeader>
        <CardContent className="p-5 pt-0">
          {openAlertsList.length === 0 ? (
            <EmptyState>No open system alerts — all hardware and dogs are operating normally 🐾</EmptyState>
          ) : (
            openAlertsList.map((alert) => (
              <AlertCard
                key={alert.id}
                alert={alert}
                dogName={dogNames.get(alert.dog_id)}
                onAcknowledge={async (a) => {
                  const userId = session?.user.id;
                  if (!userId) return;
                  const updated = await acknowledgeAlert(supabase, a.id, userId);
                  if (updated) {
                    setOpenAlertsList((prev) => prev.filter((x) => x.id !== updated.id));
                  }
                }}
              />
            ))
          )}
        </CardContent>
      </Card>
    </div>
  );
}

const ROLE_BADGE_STYLE: Record<UserRole, string> = {
  admin: "bg-purple-100 text-purple-800 border border-purple-200 font-semibold",
  veterinarian: "bg-blue-100 text-blue-800 border border-blue-200 font-semibold",
  vet_staff: "bg-teal-100 text-teal-800 border border-teal-200 font-semibold",
  owner: "bg-amber-100 text-amber-800 border border-amber-200 font-semibold",
};

/** User Accounts Tab with Multi-Select Bulk Deactivate / Delete */
function UsersTab({
  users,
  clinics,
  currentUserId,
  onChanged,
  onCreated,
  onDeleted,
  onBulkDeleted,
  onError,
}: {
  users: User[];
  clinics: Clinic[];
  currentUserId: string | null;
  onChanged: (u: User) => void;
  onCreated: (u: User) => void;
  onDeleted: (id: string, name: string) => void;
  onBulkDeleted: (deletedIds: string[], count: number) => void;
  onError: (message: string) => void;
}) {
  const [searchParams] = useSearchParams();
  const roleParam = searchParams.get("role");
  const actionParam = searchParams.get("action");

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [newRole, setNewRole] = useState<UserRole>("owner");
  const [newClinicId, setNewClinicId] = useState("");
  const [saving, setSaving] = useState(false);
  const [addOpen, setAddOpen] = useState(false);

  const [viewingUser, setViewingUser] = useState<User | null>(null);

  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [editRole, setEditRole] = useState<UserRole>("owner");
  const [editClinicId, setEditClinicId] = useState("");
  const [editSaving, setEditSaving] = useState(false);

  const [pendingDelete, setPendingDelete] = useState<User | null>(null);
  const [deleteMode, setDeleteMode] = useState<"deactivate" | "hard">("deactivate");
  const [reassignOwnerId, setReassignOwnerId] = useState<string>("");
  const [deleting, setDeleting] = useState(false);

  // Multi-select bulk state
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false);
  const [bulkDeleting, setBulkDeleting] = useState(false);
  const [bulkDeleteMode, setBulkDeleteMode] = useState<"deactivate" | "hard">("deactivate");

  const clinicNames = useMemo(() => new Map(clinics.map((c) => [c.id, c.name])), [clinics]);

  useEffect(() => {
    if (actionParam === "new") {
      setAddOpen(true);
    }
  }, [actionParam]);

  const filteredUsers = useMemo(() => {
    if (!roleParam) return users;
    if (roleParam === "vet") {
      return users.filter((u) => u.role === "vet_staff" || u.role === "veterinarian");
    }
    return users.filter((u) => u.role === roleParam);
  }, [users, roleParam]);

  const selectableUsers = useMemo(
    () => filteredUsers.filter((u) => u.id !== currentUserId),
    [filteredUsers, currentUserId],
  );

  const toggleSelectAll = () => {
    if (selectedIds.size === selectableUsers.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(selectableUsers.map((u) => u.id)));
    }
  };

  const toggleSelect = (id: string) => {
    if (id === currentUserId) return; // Superadmin safety lock
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  async function handleBulkDelete() {
    const ids = Array.from(selectedIds);
    if (ids.length === 0) return;
    setBulkDeleting(true);
    try {
      const res = await bulkDeleteUserAccounts(supabase, ids, { mode: bulkDeleteMode });
      if (res.success.length > 0) {
        onBulkDeleted(res.success, res.success.length);
        setSelectedIds(new Set());
        setBulkDeleteOpen(false);
      }
      if (res.failed.length > 0) {
        onError(`Failed to process ${res.failed.length} account(s): ${res.failed[0].error}`);
      }
    } catch (err) {
      onError(friendlyError(err, "bulk process user accounts"));
    } finally {
      setBulkDeleting(false);
    }
  }

  async function confirmDelete() {
    if (!pendingDelete) return;
    setDeleting(true);
    try {
      const res = await deleteUserAccount(supabase, pendingDelete.id, {
        mode: deleteMode,
        reassignOwnerId: reassignOwnerId === "" ? undefined : reassignOwnerId,
      });
      if (res.action === "deactivated") {
        onChanged({ ...pendingDelete, is_active: false, clinic_id: null });
      } else {
        onDeleted(pendingDelete.id, pendingDelete.name);
      }
      setPendingDelete(null);
      setReassignOwnerId("");
    } catch (err) {
      onError(friendlyError(err, deleteMode === "deactivate" ? "deactivate the user" : "delete the user"));
    } finally {
      setDeleting(false);
    }
  }

  async function handleReactivate(u: User) {
    try {
      await reactivateUserAccount(supabase, u.id);
      onChanged({ ...u, is_active: true });
    } catch (err) {
      onError(friendlyError(err, "reactivate the user"));
    }
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      const user = await createUserAccount(supabase, {
        name: name.trim(),
        email: email.trim(),
        password,
        role: newRole,
        clinicId: newClinicId === "" ? null : newClinicId,
      });
      setName("");
      setEmail("");
      setPassword("");
      setNewRole("owner");
      setNewClinicId("");
      onCreated(user);
      setAddOpen(false);
    } catch (err) {
      onError(friendlyError(err, "create the user"));
    } finally {
      setSaving(false);
    }
  }

  async function saveEdit(e: FormEvent) {
    e.preventDefault();
    if (!editingUser) return;
    setEditSaving(true);
    try {
      const updated = await updateUserRoleClinic(
        supabase,
        editingUser.id,
        editRole,
        editClinicId === "" ? null : editClinicId,
      );
      onChanged(updated);
      setEditingUser(null);
    } catch (err) {
      onError(friendlyError(err, "update the user"));
    } finally {
      setEditSaving(false);
    }
  }

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-4">
        <div>
          <CardTitle className="flex items-center gap-2">
            <span>Users</span>
            {roleParam && (
              <span className="rounded-full bg-brand-soft px-2.5 py-0.5 text-xs font-semibold text-brand-strong">
                Filtered: {roleParam === "vet" ? "Staff & Vets" : roleParam}
              </span>
            )}
          </CardTitle>
          <CardDescription>
            Manage accounts, assign roles and clinics, or perform bulk deactivations.
          </CardDescription>
        </div>
        <div className="flex items-center gap-2">
          {selectedIds.size > 0 && (
            <Button
              variant="destructive"
              size="sm"
              onClick={() => setBulkDeleteOpen(true)}
              className="font-bold shadow-xs flex items-center gap-1.5"
            >
              <Trash2 size={13} />
              <span>Bulk Delete / Deactivate ({selectedIds.size})</span>
            </Button>
          )}
          <Button type="button" onClick={() => setAddOpen(true)}>
            <Plus size={14} /> Add user
          </Button>
        </div>
      </CardHeader>
      <CardContent className="flex flex-col gap-5">
        <Table>
          <THead>
            <Tr className="border-t-0">
              <Th className="w-10 text-center">
                <input
                  type="checkbox"
                  aria-label="Select all users"
                  checked={selectedIds.size === selectableUsers.length && selectableUsers.length > 0}
                  onChange={toggleSelectAll}
                  className="accent-[#0088D6] rounded h-4 w-4 cursor-pointer"
                />
              </Th>
              <Th>Name</Th>
              <Th>Email</Th>
              <Th>Role</Th>
              <Th>Status</Th>
              <Th>Clinic</Th>
              <Th>Actions</Th>
            </Tr>
          </THead>
          <TBody>
            {filteredUsers.map((u) => {
              const isSelected = selectedIds.has(u.id);
              const isSelf = u.id === currentUserId;
              return (
                <Tr key={u.id} className={isSelected ? "bg-brand-soft/40" : undefined}>
                  <Td className="text-center">
                    <input
                      type="checkbox"
                      aria-label={`Select ${u.name}`}
                      disabled={isSelf}
                      title={isSelf ? "You cannot delete your own active admin account" : undefined}
                      checked={isSelected}
                      onChange={() => toggleSelect(u.id)}
                      className="accent-[#0088D6] rounded h-4 w-4 cursor-pointer disabled:opacity-30"
                    />
                  </Td>
                  <Td className="font-semibold">
                    <div className="flex items-center gap-2">
                      <span>{u.name}</span>
                      {isSelf && (
                        <span className="rounded-full bg-surface-alt border border-hairline px-2 py-0.2 text-[10px] font-bold text-ink-muted">
                          You
                        </span>
                      )}
                    </div>
                  </Td>
                  <Td className="text-ink-muted">{u.email}</Td>
                  <Td>
                    <span className={cn("inline-flex items-center rounded-pill px-2.5 py-0.5 text-xs capitalize", ROLE_BADGE_STYLE[u.role])}>
                      {u.role.replace("_", " ")}
                    </span>
                  </Td>
                  <Td>
                    {u.is_active === false ? (
                      <span className="inline-flex items-center rounded-pill bg-surface-alt px-2.5 py-0.5 text-xs font-medium text-ink-muted">
                        Deactivated
                      </span>
                    ) : (
                      <span className="inline-flex items-center rounded-pill bg-emerald-100 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-300 px-2.5 py-0.5 text-xs font-medium">
                        Active
                      </span>
                    )}
                  </Td>
                  <Td className="text-ink-muted">
                    {u.clinic_id ? (clinicNames.get(u.clinic_id) ?? "— none —") : "— none —"}
                  </Td>
                  <Td>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        aria-label={`View details for ${u.name}`}
                        title="View User Details"
                        onClick={() => setViewingUser(u)}
                        className="flex h-8 w-8 items-center justify-center rounded-md bg-surface-alt text-ink-muted transition-colors duration-fast hover:bg-brand-soft hover:text-brand-strong"
                      >
                        <Eye size={15} />
                      </button>

                      <button
                        type="button"
                        aria-label={`Edit ${u.name}`}
                        title="Edit User Role & Clinic"
                        onClick={() => {
                          setEditingUser(u);
                          setEditRole(u.role);
                          setEditClinicId(u.clinic_id ?? "");
                        }}
                        className="flex h-8 w-8 items-center justify-center rounded-md bg-brand-soft text-brand-strong transition-colors duration-fast hover:bg-brand hover:text-white"
                      >
                        <Pencil size={15} />
                      </button>

                      {u.is_active === false ? (
                        <button
                          type="button"
                          aria-label={`Reactivate ${u.name}`}
                          title="Reactivate User Account"
                          onClick={() => handleReactivate(u)}
                          className="flex h-8 w-8 items-center justify-center rounded-md bg-emerald-100 text-emerald-800 hover:bg-emerald-200 transition-colors duration-fast"
                        >
                          <RotateCcw size={15} />
                        </button>
                      ) : !isSelf ? (
                        <button
                          type="button"
                          aria-label={`Delete or deactivate ${u.name}`}
                          title="Delete or Deactivate Account"
                          onClick={() => {
                            setPendingDelete(u);
                            setDeleteMode("deactivate");
                            setReassignOwnerId("");
                          }}
                          className="flex h-8 w-8 items-center justify-center rounded-md bg-high-soft text-high-fg transition-colors duration-fast hover:bg-high hover:text-white"
                        >
                          <Trash2 size={15} />
                        </button>
                      ) : (
                        <div className="h-8 w-8" />
                      )}
                    </div>
                  </Td>
                </Tr>
              );
            })}
          </TBody>
        </Table>
      </CardContent>

      {/* Bulk Delete Modal */}
      <Dialog
        open={bulkDeleteOpen}
        onClose={() => setBulkDeleteOpen(false)}
        title={`Bulk Process (${selectedIds.size} Users)`}
      >
        <div className="flex flex-col gap-4 text-sm">
          <p className="text-ink-muted m-0">
            You are about to process <strong className="text-ink">{selectedIds.size} user accounts</strong> simultaneously.
          </p>

          <div className="flex flex-col gap-2 rounded-lg border border-hairline bg-surface-alt p-3">
            <Label className="font-bold">Select Action:</Label>
            <div className="flex flex-col gap-1.5">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name="bulk-mode"
                  checked={bulkDeleteMode === "deactivate"}
                  onChange={() => setBulkDeleteMode("deactivate")}
                  className="accent-[#0088D6]"
                />
                <span className="font-medium text-ink">Soft Deactivate (Recommended)</span>
              </label>
              <span className="text-xs text-ink-muted pl-5">
                Revokes login access immediately while safely preserving patient clinical history.
              </span>

              <label className="flex items-center gap-2 cursor-pointer mt-2">
                <input
                  type="radio"
                  name="bulk-mode"
                  checked={bulkDeleteMode === "hard"}
                  onChange={() => setBulkDeleteMode("hard")}
                  className="accent-red-600"
                />
                <span className="font-bold text-red-600">Permanent Purge (Hard Delete)</span>
              </label>
              <span className="text-xs text-ink-muted pl-5">
                Permanently deletes the auth and public profiles. Cannot be undone.
              </span>
            </div>
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button variant="secondary" onClick={() => setBulkDeleteOpen(false)} disabled={bulkDeleting}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleBulkDelete} disabled={bulkDeleting}>
              {bulkDeleting ? "Processing…" : `Confirm Bulk ${bulkDeleteMode === "hard" ? "Purge" : "Deactivation"}`}
            </Button>
          </div>
        </div>
      </Dialog>

      {/* Add User Dialog */}
      <Dialog open={addOpen} onClose={() => setAddOpen(false)} title="Add user account">
        <form onSubmit={submit} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1">
            <Label htmlFor="user-name">Full name</Label>
            <Input
              id="user-name"
              required
              placeholder="e.g. Dr. Jane Smith"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>

          <div className="flex flex-col gap-1">
            <Label htmlFor="user-email">Email address</Label>
            <Input
              id="user-email"
              type="email"
              required
              placeholder="e.g. jane@clinic.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>

          <div className="flex flex-col gap-1">
            <Label htmlFor="user-password">Initial password</Label>
            <Input
              id="user-password"
              type="password"
              required
              minLength={6}
              placeholder="At least 6 characters"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>

          <div className="flex flex-col gap-1">
            <Label htmlFor="user-role">Role</Label>
            <Select
              id="user-role"
              className="h-10 w-full"
              value={newRole}
              onChange={(e) => setNewRole(e.target.value as UserRole)}
            >
              <option value="owner">Dog Owner</option>
              <option value="vet_staff">Vet Staff</option>
              <option value="veterinarian">Veterinarian</option>
              <option value="admin">Admin</option>
            </Select>
          </div>

          <div className="flex flex-col gap-1">
            <Label htmlFor="user-clinic">Assigned Clinic (Optional)</Label>
            <Select
              id="user-clinic"
              className="h-10 w-full"
              value={newClinicId}
              onChange={(e) => setNewClinicId(e.target.value)}
            >
              <option value="">— None (Independent) —</option>
              {clinics.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="secondary" onClick={() => setAddOpen(false)} disabled={saving}>
              Cancel
            </Button>
            <Button type="submit" disabled={saving}>
              {saving ? "Creating…" : "Create account"}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* View User Details Dialog */}
      <Dialog
        open={viewingUser !== null}
        onClose={() => setViewingUser(null)}
        title={viewingUser ? `User Details — ${viewingUser.name}` : "User Details"}
      >
        {viewingUser && (
          <div className="flex flex-col gap-3 text-sm">
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Name</span>
              <span className="col-span-2 font-medium text-ink">{viewingUser.name}</span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Email</span>
              <span className="col-span-2 font-medium text-ink">{viewingUser.email}</span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Role</span>
              <span className="col-span-2">
                <span className={cn("inline-flex items-center rounded-pill px-2 py-0.5 text-xs capitalize", ROLE_BADGE_STYLE[viewingUser.role])}>
                  {viewingUser.role.replace("_", " ")}
                </span>
              </span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Status</span>
              <span className="col-span-2">
                {viewingUser.is_active === false ? (
                  <span className="text-high-fg font-medium">Deactivated</span>
                ) : (
                  <span className="text-emerald-600 font-medium">Active</span>
                )}
              </span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Clinic</span>
              <span className="col-span-2 text-ink">
                {viewingUser.clinic_id ? (clinicNames.get(viewingUser.clinic_id) ?? "—") : "— none —"}
              </span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Created (PST)</span>
              <span className="col-span-2 text-ink-muted text-xs">
                {formatPhilippineTime(viewingUser.created_at)}
              </span>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="secondary" onClick={() => setViewingUser(null)}>
                Close
              </Button>
              <Button
                onClick={() => {
                  const u = viewingUser;
                  setViewingUser(null);
                  setEditingUser(u);
                  setEditRole(u.role);
                  setEditClinicId(u.clinic_id ?? "");
                }}
              >
                <Pencil size={14} /> Edit user
              </Button>
            </div>
          </div>
        )}
      </Dialog>

      {/* Edit User Dialog */}
      <Dialog open={editingUser !== null} onClose={() => setEditingUser(null)} title="Edit user">
        {editingUser && (
          <form onSubmit={saveEdit} className="flex flex-col gap-4">
            <div className="flex flex-col gap-1">
              <Label>Name</Label>
              <div className="text-sm font-semibold text-ink">{editingUser.name}</div>
            </div>
            <div className="flex flex-col gap-1">
              <Label>Email</Label>
              <div className="text-sm text-ink-muted">{editingUser.email}</div>
            </div>
            <div className="flex flex-col gap-1">
              <Label htmlFor="edit-role">Role</Label>
              <Select
                id="edit-role"
                className="h-10 w-full"
                value={editRole}
                onChange={(e) => setEditRole(e.target.value as UserRole)}
              >
                <option value="owner">Dog Owner</option>
                <option value="vet_staff">Vet Staff</option>
                <option value="veterinarian">Veterinarian</option>
                <option value="admin">Admin</option>
              </Select>
            </div>
            <div className="flex flex-col gap-1">
              <Label htmlFor="edit-clinic">Assigned Clinic</Label>
              <Select
                id="edit-clinic"
                className="h-10 w-full"
                value={editClinicId}
                onChange={(e) => setEditClinicId(e.target.value)}
              >
                <option value="">— None (Independent) —</option>
                {clinics.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </Select>
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="secondary" onClick={() => setEditingUser(null)} disabled={editSaving}>
                Cancel
              </Button>
              <Button type="submit" disabled={editSaving}>
                {editSaving ? "Saving…" : "Save changes"}
              </Button>
            </div>
          </form>
        )}
      </Dialog>

      {/* Single Delete Dialog */}
      <Dialog
        open={pendingDelete !== null}
        onClose={() => setPendingDelete(null)}
        title={pendingDelete ? `Deactivate or Delete — ${pendingDelete.name}` : "Delete User"}
      >
        {pendingDelete && (
          <div className="flex flex-col gap-4 text-sm">
            <p className="text-ink-muted m-0">
              Choose how you want to handle <strong className="text-ink">{pendingDelete.name}</strong> ({pendingDelete.email}):
            </p>

            <div className="flex flex-col gap-2 rounded-lg border border-hairline bg-surface-alt p-3">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name="del-mode"
                  checked={deleteMode === "deactivate"}
                  onChange={() => setDeleteMode("deactivate")}
                  className="accent-[#0088D6]"
                />
                <span className="font-medium text-ink">Deactivate account (Soft delete)</span>
              </label>
              <span className="text-xs text-ink-muted pl-5">
                Revokes login access immediately while keeping historical clinical records intact.
              </span>

              <label className="flex items-center gap-2 cursor-pointer mt-2">
                <input
                  type="radio"
                  name="del-mode"
                  checked={deleteMode === "hard"}
                  onChange={() => setDeleteMode("hard")}
                  className="accent-red-600"
                />
                <span className="font-bold text-red-600">Permanent Purge (Hard delete)</span>
              </label>
              <span className="text-xs text-ink-muted pl-5">
                Permanently wipes the account from authentication and public tables.
              </span>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="secondary" onClick={() => setPendingDelete(null)} disabled={deleting}>
                Cancel
              </Button>
              <Button variant="destructive" onClick={confirmDelete} disabled={deleting}>
                {deleting ? "Processing…" : `Confirm ${deleteMode === "hard" ? "Purge" : "Deactivation"}`}
              </Button>
            </div>
          </div>
        )}
      </Dialog>
    </Card>
  );
}

function clinicMapEmbedUrl(address: string): string {
  return `https://maps.google.com/maps?q=${encodeURIComponent(address)}&output=embed`;
}

function ClinicFields({
  name,
  address,
  contact,
  onName,
  onAddress,
  onContact,
  idPrefix,
}: {
  name: string;
  address: string;
  contact: string;
  onName: (v: string) => void;
  onAddress: (v: string) => void;
  onContact: (v: string) => void;
  idPrefix: string;
}) {
  return (
    <>
      <div className="flex flex-col gap-1">
        <Label htmlFor={`${idPrefix}-name`}>Name</Label>
        <Input id={`${idPrefix}-name`} value={name} onChange={(e) => onName(e.target.value)} required />
      </div>
      <div className="flex flex-col gap-1">
        <Label htmlFor={`${idPrefix}-address`}>Address</Label>
        <Input id={`${idPrefix}-address`} value={address} onChange={(e) => onAddress(e.target.value)} />
      </div>
      {address.trim() !== "" && (
        <div className="overflow-hidden rounded-lg border border-hairline">
          <iframe
            title="Clinic location preview"
            className="h-40 w-full"
            loading="lazy"
            src={clinicMapEmbedUrl(address)}
          />
        </div>
      )}
      <div className="flex flex-col gap-1">
        <Label htmlFor={`${idPrefix}-contact`}>Contact</Label>
        <Input id={`${idPrefix}-contact`} value={contact} onChange={(e) => onContact(e.target.value)} />
      </div>
    </>
  );
}

/** Partner Clinics Tab with Multi-Select Bulk Delete */
function ClinicsTab({
  clinics,
  onCreated,
  onChanged,
  onDeleted,
  onBulkDeleted,
  onError,
}: {
  clinics: Clinic[];
  onCreated: (c: Clinic) => void;
  onChanged: (c: Clinic) => void;
  onDeleted: (id: string, name: string) => void;
  onBulkDeleted: (deletedIds: string[], count: number) => void;
  onError: (message: string) => void;
}) {
  const [name, setName] = useState("");
  const [address, setAddress] = useState("");
  const [contact, setContact] = useState("");
  const [saving, setSaving] = useState(false);
  const [addOpen, setAddOpen] = useState(false);

  const [viewingClinic, setViewingClinic] = useState<Clinic | null>(null);

  const [editing, setEditing] = useState<Clinic | null>(null);
  const [editName, setEditName] = useState("");
  const [editAddress, setEditAddress] = useState("");
  const [editContact, setEditContact] = useState("");
  const [editSaving, setEditSaving] = useState(false);

  const [pendingDelete, setPendingDelete] = useState<Clinic | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Multi-select bulk state
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false);
  const [bulkDeleting, setBulkDeleting] = useState(false);

  const toggleSelectAll = () => {
    if (selectedIds.size === clinics.length) setSelectedIds(new Set());
    else setSelectedIds(new Set(clinics.map((c) => c.id)));
  };

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  async function handleBulkDelete() {
    const ids = Array.from(selectedIds);
    if (ids.length === 0) return;
    setBulkDeleting(true);
    try {
      const res = await bulkDeleteClinics(supabase, ids);
      if (res.success.length > 0) {
        onBulkDeleted(res.success, res.success.length);
        setSelectedIds(new Set());
        setBulkDeleteOpen(false);
      }
      if (res.failed.length > 0) {
        onError(`Failed to delete ${res.failed.length} clinic(s): ${res.failed[0].error}`);
      }
    } catch (err) {
      onError(friendlyError(err, "bulk delete clinics"));
    } finally {
      setBulkDeleting(false);
    }
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (name.trim() === "") return;
    setSaving(true);
    try {
      const clinic = await createClinic(supabase, {
        name: name.trim(),
        address: address.trim() === "" ? null : address.trim(),
        contact_number: contact.trim() === "" ? null : contact.trim(),
      });
      setName("");
      setAddress("");
      setContact("");
      onCreated(clinic);
      setAddOpen(false);
    } catch (err) {
      onError(friendlyError(err, "create the clinic"));
    } finally {
      setSaving(false);
    }
  }

  function startEdit(c: Clinic) {
    setEditing(c);
    setEditName(c.name);
    setEditAddress(c.address ?? "");
    setEditContact(c.contact_number ?? "");
  }

  async function saveEdit(e: FormEvent) {
    e.preventDefault();
    if (!editing || editName.trim() === "") return;
    setEditSaving(true);
    try {
      const clinic = await updateClinic(supabase, editing.id, {
        name: editName.trim(),
        address: editAddress.trim() === "" ? null : editAddress.trim(),
        contact_number: editContact.trim() === "" ? null : editContact.trim(),
      });
      onChanged(clinic);
      setEditing(null);
    } catch (err) {
      onError(friendlyError(err, "update the clinic"));
    } finally {
      setEditSaving(false);
    }
  }

  async function confirmDelete() {
    if (!pendingDelete) return;
    setDeleting(true);
    try {
      await deleteClinic(supabase, pendingDelete.id);
      onDeleted(pendingDelete.id, pendingDelete.name);
      setPendingDelete(null);
    } catch (err) {
      onError(friendlyError(err, "delete the clinic"));
    } finally {
      setDeleting(false);
    }
  }

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-4">
        <div>
          <CardTitle>Clinics</CardTitle>
          <CardDescription>
            Manage partner clinics, addresses, and map locations.
          </CardDescription>
        </div>
        <div className="flex items-center gap-2">
          {selectedIds.size > 0 && (
            <Button
              variant="destructive"
              size="sm"
              onClick={() => setBulkDeleteOpen(true)}
              className="font-bold shadow-xs flex items-center gap-1.5"
            >
              <Trash2 size={13} />
              <span>Bulk Delete ({selectedIds.size})</span>
            </Button>
          )}
          <Button type="button" onClick={() => setAddOpen(true)}>
            <Plus size={14} /> Add clinic
          </Button>
        </div>
      </CardHeader>
      <CardContent className="flex flex-col gap-5">
        <Table>
          <THead>
            <Tr className="border-t-0">
              <Th className="w-10 text-center">
                <input
                  type="checkbox"
                  aria-label="Select all clinics"
                  checked={selectedIds.size === clinics.length && clinics.length > 0}
                  onChange={toggleSelectAll}
                  className="accent-[#0088D6] rounded h-4 w-4 cursor-pointer"
                />
              </Th>
              <Th>Name</Th>
              <Th>Address</Th>
              <Th>Contact</Th>
              <Th>Actions</Th>
            </Tr>
          </THead>
          <TBody>
            {clinics.map((c) => {
              const isSelected = selectedIds.has(c.id);
              return (
                <Tr key={c.id} className={isSelected ? "bg-brand-soft/40" : undefined}>
                  <Td className="text-center">
                    <input
                      type="checkbox"
                      aria-label={`Select ${c.name}`}
                      checked={isSelected}
                      onChange={() => toggleSelect(c.id)}
                      className="accent-[#0088D6] rounded h-4 w-4 cursor-pointer"
                    />
                  </Td>
                  <Td className="font-semibold">{c.name}</Td>
                  <Td className="text-ink-muted">{c.address ?? "—"}</Td>
                  <Td className="text-ink-muted">{c.contact_number ?? "—"}</Td>
                  <Td>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        aria-label={`View details for ${c.name}`}
                        title="View Clinic Details"
                        onClick={() => setViewingClinic(c)}
                        className="flex h-8 w-8 items-center justify-center rounded-md bg-surface-alt text-ink-muted transition-colors duration-fast hover:bg-brand-soft hover:text-brand-strong"
                      >
                        <Eye size={15} />
                      </button>

                      <button
                        type="button"
                        aria-label={`Edit ${c.name}`}
                        title="Edit Clinic"
                        onClick={() => startEdit(c)}
                        className="flex h-8 w-8 items-center justify-center rounded-md bg-brand-soft text-brand-strong transition-colors duration-fast hover:bg-brand hover:text-white"
                      >
                        <Pencil size={15} />
                      </button>

                      <button
                        type="button"
                        aria-label={`Delete ${c.name}`}
                        title="Delete Clinic"
                        onClick={() => setPendingDelete(c)}
                        className="flex h-8 w-8 items-center justify-center rounded-md bg-high-soft text-high-fg transition-colors duration-fast hover:bg-high hover:text-white"
                      >
                        <Trash2 size={15} />
                      </button>
                    </div>
                  </Td>
                </Tr>
              );
            })}
          </TBody>
        </Table>
      </CardContent>

      {/* Bulk Delete Clinics Modal */}
      <ConfirmDeleteDialog
        open={bulkDeleteOpen}
        title={`Bulk Delete Clinics (${selectedIds.size})`}
        description={`Are you sure you want to permanently delete these ${selectedIds.size} partner clinics? Ensure no staff or dogs remain assigned to them.`}
        busy={bulkDeleting}
        onConfirm={handleBulkDelete}
        onClose={() => setBulkDeleteOpen(false)}
      />

      {/* Add Clinic Dialog */}
      <Dialog open={addOpen} onClose={() => setAddOpen(false)} title="Add clinic">
        <form onSubmit={submit} className="flex flex-col gap-4">
          <ClinicFields
            name={name}
            address={address}
            contact={contact}
            onName={setName}
            onAddress={setAddress}
            onContact={setContact}
            idPrefix="add-clinic"
          />
          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="secondary" onClick={() => setAddOpen(false)} disabled={saving}>
              Cancel
            </Button>
            <Button type="submit" disabled={saving || name.trim() === ""}>
              {saving ? "Creating…" : "Create clinic"}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* View Clinic Dialog */}
      <Dialog
        open={viewingClinic !== null}
        onClose={() => setViewingClinic(null)}
        title={viewingClinic ? `Clinic Details — ${viewingClinic.name}` : "Clinic Details"}
      >
        {viewingClinic && (
          <div className="flex flex-col gap-3 text-sm">
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Name</span>
              <span className="col-span-2 font-medium text-ink">{viewingClinic.name}</span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Address</span>
              <span className="col-span-2 font-medium text-ink">{viewingClinic.address ?? "—"}</span>
            </div>
            {viewingClinic.address && (
              <div className="overflow-hidden rounded-lg border border-hairline my-1">
                <iframe
                  title="Clinic location preview"
                  className="h-40 w-full"
                  loading="lazy"
                  src={clinicMapEmbedUrl(viewingClinic.address)}
                />
              </div>
            )}
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Contact</span>
              <span className="col-span-2 font-medium text-ink">{viewingClinic.contact_number ?? "—"}</span>
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="secondary" onClick={() => setViewingClinic(null)}>
                Close
              </Button>
              <Button
                onClick={() => {
                  const c = viewingClinic;
                  setViewingClinic(null);
                  startEdit(c);
                }}
              >
                <Pencil size={14} /> Edit clinic
              </Button>
            </div>
          </div>
        )}
      </Dialog>

      {/* Edit Clinic Dialog */}
      <Dialog open={editing !== null} onClose={() => setEditing(null)} title="Edit clinic">
        {editing && (
          <form onSubmit={saveEdit} className="flex flex-col gap-4">
            <ClinicFields
              name={editName}
              address={editAddress}
              contact={editContact}
              onName={setEditName}
              onAddress={setEditAddress}
              onContact={setEditContact}
              idPrefix="edit-clinic"
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="secondary" onClick={() => setEditing(null)} disabled={editSaving}>
                Cancel
              </Button>
              <Button type="submit" disabled={editSaving || editName.trim() === ""}>
                {editSaving ? "Saving…" : "Save changes"}
              </Button>
            </div>
          </form>
        )}
      </Dialog>

      <ConfirmDeleteDialog
        open={pendingDelete !== null}
        title="Delete clinic"
        description={
          pendingDelete
            ? `Delete ${pendingDelete.name}? Clinics with active staff or dogs can't be deleted — reassign those first.`
            : ""
        }
        busy={deleting}
        onConfirm={confirmDelete}
        onClose={() => setPendingDelete(null)}
      />
    </Card>
  );
}

const DEVICE_STATUS_BADGE_STYLE: Record<DeviceStatus, string> = {
  active: "bg-emerald-100 text-emerald-800 border border-emerald-200 font-semibold",
  offline: "bg-red-100 text-red-800 border border-red-200 font-semibold",
  inactive: "bg-gray-100 text-gray-800 border border-gray-200 font-semibold",
  maintenance: "bg-amber-100 text-amber-800 border border-amber-200 font-semibold",
};

/** Device Management Tab with Multi-Select Bulk Decommission / Delete */
function DevicesTab({
  devices,
  dogs,
  dogNames,
  onChanged,
  onRegistered,
  onDeleted,
  onBulkDeleted,
  onToast,
}: {
  devices: Device[];
  dogs: Dog[];
  dogNames: Map<string, string>;
  onChanged: (d: Device) => void;
  onRegistered: (d: Device) => void;
  onDeleted: (id: string) => void;
  onBulkDeleted: (deletedIds: string[], count: number) => void;
  onToast: (kind: "success" | "error", message: string) => void;
}) {
  const [code, setCode] = useState("");
  const [firmware, setFirmware] = useState("0.1.0");
  const [saving, setSaving] = useState(false);
  const [addOpen, setAddOpen] = useState(false);

  const [viewingDevice, setViewingDevice] = useState<Device | null>(null);

  const [editingDevice, setEditingDevice] = useState<Device | null>(null);
  const [editStatus, setEditStatus] = useState<DeviceStatus>("active");
  const [editDogId, setEditDogId] = useState<string>("");
  const [editSaving, setEditSaving] = useState(false);

  const [pendingDelete, setPendingDelete] = useState<Device | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Multi-select bulk state
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false);
  const [bulkDeleting, setBulkDeleting] = useState(false);

  const toggleSelectAll = () => {
    if (selectedIds.size === devices.length) setSelectedIds(new Set());
    else setSelectedIds(new Set(devices.map((d) => d.id)));
  };

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  async function handleBulkDelete() {
    const ids = Array.from(selectedIds);
    if (ids.length === 0) return;
    setBulkDeleting(true);
    try {
      const res = await bulkDeleteDevices(supabase, ids, true);
      const affected = [...res.deleted, ...res.deactivated];
      if (affected.length > 0) {
        onBulkDeleted(res.deleted, affected.length);
        setSelectedIds(new Set());
        setBulkDeleteOpen(false);
      }
      if (res.failed.length > 0) {
        onToast("error", `Failed on ${res.failed.length} device(s): ${res.failed[0].error}`);
      }
    } catch (err) {
      onToast("error", friendlyError(err, "bulk process devices"));
    } finally {
      setBulkDeleting(false);
    }
  }

  async function register(e: FormEvent) {
    e.preventDefault();
    if (code.trim() === "") return;
    setSaving(true);
    try {
      const device = await registerDevice(
        supabase,
        code,
        firmware.trim() === "" ? null : firmware.trim(),
      );
      setCode("");
      setFirmware("0.1.0");
      onRegistered(device);
      setAddOpen(false);
      onToast("success", `${device.device_code} registered`);
    } catch (err) {
      onToast("error", friendlyError(err, "register the device"));
    } finally {
      setSaving(false);
    }
  }

  async function patch(device: Device, patchBody: { status?: DeviceStatus; dog_id?: string | null }) {
    try {
      onChanged(await updateDevice(supabase, device.id, patchBody));
      onToast("success", `${device.device_code} updated`);
    } catch (err) {
      onToast("error", friendlyError(err, "update the device"));
    }
  }

  async function saveEditDevice(e: FormEvent) {
    e.preventDefault();
    if (!editingDevice) return;
    setEditSaving(true);
    try {
      await patch(editingDevice, {
        status: editStatus,
        dog_id: editDogId === "" ? null : editDogId,
      });
      setEditingDevice(null);
    } finally {
      setEditSaving(false);
    }
  }

  async function confirmDelete() {
    if (!pendingDelete) return;
    setDeleting(true);
    try {
      await deleteDevice(supabase, pendingDelete.id);
      onDeleted(pendingDelete.id);
      onToast("success", `${pendingDelete.device_code} deleted`);
      setPendingDelete(null);
    } catch (err) {
      onToast("error", friendlyError(err, "delete the device"));
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <Card>
        <CardHeader className="flex flex-row items-start justify-between gap-4">
          <div>
            <CardTitle>Devices</CardTitle>
            <CardDescription>
              Register harnesses, assign them to dogs, or decommission inactive hardware.
            </CardDescription>
          </div>
          <div className="flex items-center gap-2">
            {selectedIds.size > 0 && (
              <Button
                variant="destructive"
                size="sm"
                onClick={() => setBulkDeleteOpen(true)}
                className="font-bold shadow-xs flex items-center gap-1.5"
              >
                <Trash2 size={13} />
                <span>Bulk Decommission ({selectedIds.size})</span>
              </Button>
            )}
            <Button type="button" onClick={() => setAddOpen(true)}>
              <Plus size={14} /> Register device
            </Button>
          </div>
        </CardHeader>
        <CardContent className="flex flex-col gap-5">
          <Table>
            <THead>
              <Tr className="border-t-0">
                <Th className="w-10 text-center">
                  <input
                    type="checkbox"
                    aria-label="Select all devices"
                    checked={selectedIds.size === devices.length && devices.length > 0}
                    onChange={toggleSelectAll}
                    className="accent-[#0088D6] rounded h-4 w-4 cursor-pointer"
                  />
                </Th>
                <Th>Code</Th>
                <Th>Status</Th>
                <Th>Assigned dog</Th>
                <Th>Last seen (PST)</Th>
                <Th>Actions</Th>
              </Tr>
            </THead>
            <TBody>
              {devices.map((d) => {
                const isSelected = selectedIds.has(d.id);
                return (
                  <Tr key={d.id} className={isSelected ? "bg-brand-soft/40" : undefined}>
                    <Td className="text-center">
                      <input
                        type="checkbox"
                        aria-label={`Select ${d.device_code}`}
                        checked={isSelected}
                        onChange={() => toggleSelect(d.id)}
                        className="accent-[#0088D6] rounded h-4 w-4 cursor-pointer"
                      />
                    </Td>
                    <Td className="font-semibold">{d.device_code}</Td>
                    <Td>
                      <span className={cn("inline-flex items-center rounded-pill px-2.5 py-0.5 text-xs capitalize", DEVICE_STATUS_BADGE_STYLE[d.status])}>
                        {d.status}
                      </span>
                    </Td>
                    <Td className="text-ink-muted">
                      {d.dog_id ? (dogNames.get(d.dog_id) ?? "—") : "— unassigned —"}
                    </Td>
                    <Td className="text-xs text-ink-muted">
                      {d.last_seen_at ? formatPhilippineTime(d.last_seen_at) : "never"}
                    </Td>
                    <Td>
                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          aria-label={`View details for ${d.device_code}`}
                          title="View Device Details"
                          onClick={() => setViewingDevice(d)}
                          className="flex h-8 w-8 items-center justify-center rounded-md bg-surface-alt text-ink-muted transition-colors duration-fast hover:bg-brand-soft hover:text-brand-strong"
                        >
                          <Eye size={15} />
                        </button>
                        <button
                          type="button"
                          aria-label={`Edit ${d.device_code}`}
                          title="Edit Status & Dog Assignment"
                          onClick={() => {
                            setEditingDevice(d);
                            setEditStatus(d.status);
                            setEditDogId(d.dog_id ?? "");
                          }}
                          className="flex h-8 w-8 items-center justify-center rounded-md bg-brand-soft text-brand-strong transition-colors duration-fast hover:bg-brand hover:text-white"
                        >
                          <Pencil size={15} />
                        </button>
                        <button
                          type="button"
                          aria-label={`Delete ${d.device_code}`}
                          title="Delete Device"
                          onClick={() => setPendingDelete(d)}
                          className="flex h-8 w-8 items-center justify-center rounded-md bg-high-soft text-high-fg transition-colors duration-fast hover:bg-high hover:text-white"
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </Td>
                  </Tr>
                );
              })}
            </TBody>
          </Table>
        </CardContent>

        {/* Bulk Delete Devices Modal */}
        <ConfirmDeleteDialog
          open={bulkDeleteOpen}
          title={`Bulk Delete Devices (${selectedIds.size})`}
          description={`Are you sure you want to delete these ${selectedIds.size} devices? Associated telemetry history and linkages will be cleaned up.`}
          busy={bulkDeleting}
          onConfirm={handleBulkDelete}
          onClose={() => setBulkDeleteOpen(false)}
        />

        {/* Register Device Dialog */}
        <Dialog open={addOpen} onClose={() => setAddOpen(false)} title="Register device">
          <form className="flex flex-col gap-3" onSubmit={register}>
            <div className="flex flex-col gap-1">
              <Label htmlFor="device-code">Device code</Label>
              <Input
                id="device-code"
                value={code}
                onChange={(e) => setCode(e.target.value)}
                placeholder="FURFEEL-DEV-0003"
                required
              />
            </div>
            <div className="flex flex-col gap-1">
              <Label htmlFor="device-fw">Firmware</Label>
              <Input
                id="device-fw"
                value={firmware}
                onChange={(e) => setFirmware(e.target.value)}
                placeholder="0.1.0"
              />
            </div>
            <div className="flex justify-end gap-2">
              <Button type="button" variant="secondary" onClick={() => setAddOpen(false)} disabled={saving}>
                Cancel
              </Button>
              <Button type="submit" disabled={saving || code.trim() === ""}>
                {saving ? "Registering…" : "Register device"}
              </Button>
            </div>
          </form>
        </Dialog>

        {/* View Device Dialog */}
        <Dialog open={viewingDevice !== null} onClose={() => setViewingDevice(null)} title="Device details">
          {viewingDevice && (
            <div className="flex flex-col gap-4 py-1">
              <div className="flex flex-col gap-1 border-b border-hairline pb-3">
                <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Device Code</span>
                <span className="text-base font-bold text-ink">{viewingDevice.device_code}</span>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="flex flex-col gap-1">
                  <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Status</span>
                  <div>
                    <span className={cn("inline-flex items-center rounded-pill px-2.5 py-0.5 text-xs capitalize", DEVICE_STATUS_BADGE_STYLE[viewingDevice.status])}>
                      {viewingDevice.status}
                    </span>
                  </div>
                </div>

                <div className="flex flex-col gap-1">
                  <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Firmware Version</span>
                  <span className="text-sm font-medium text-ink">{viewingDevice.firmware_version ?? "—"}</span>
                </div>

                <div className="flex flex-col gap-1">
                  <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Assigned Dog</span>
                  <span className="text-sm font-medium text-ink">
                    {viewingDevice.dog_id ? (dogNames.get(viewingDevice.dog_id) ?? "—") : "— unassigned —"}
                  </span>
                </div>

                <div className="flex flex-col gap-1">
                  <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Last Seen (PST)</span>
                  <span className="text-sm font-medium text-ink">
                    {viewingDevice.last_seen_at ? formatPhilippineTime(viewingDevice.last_seen_at) : "never"}
                  </span>
                </div>
              </div>

              <div className="flex flex-col gap-1 rounded-md bg-surface-alt p-3">
                <span className="text-[11px] font-semibold text-ink-muted">Device ID</span>
                <span className="font-mono text-xs text-ink">{viewingDevice.id}</span>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <Button variant="secondary" onClick={() => setViewingDevice(null)}>
                  Close
                </Button>
                <Button
                  onClick={() => {
                    const d = viewingDevice;
                    setViewingDevice(null);
                    setEditingDevice(d);
                    setEditStatus(d.status);
                    setEditDogId(d.dog_id ?? "");
                  }}
                >
                  <Pencil size={14} /> Edit device
                </Button>
              </div>
            </div>
          )}
        </Dialog>

        {/* Edit Device Dialog */}
        <Dialog open={editingDevice !== null} onClose={() => setEditingDevice(null)} title="Edit device">
          {editingDevice && (
            <form className="flex flex-col gap-4" onSubmit={saveEditDevice}>
              <div className="flex flex-col gap-1">
                <Label>Device</Label>
                <div className="text-sm font-semibold text-ink">{editingDevice.device_code}</div>
              </div>

              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-device-status">Status</Label>
                <Select
                  id="edit-device-status"
                  className="h-10 w-full"
                  value={editStatus}
                  onChange={(e) => setEditStatus(e.target.value as DeviceStatus)}
                >
                  {DEVICE_STATUSES.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </Select>
              </div>

              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-device-dog">Assigned Dog</Label>
                <Select
                  id="edit-device-dog"
                  className="h-10 w-full"
                  value={editDogId}
                  onChange={(e) => setEditDogId(e.target.value)}
                >
                  <option value="">— unassigned —</option>
                  {dogs.map((dog) => (
                    <option key={dog.id} value={dog.id}>
                      {dogNames.get(dog.id) ?? dog.name}
                    </option>
                  ))}
                </Select>
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <Button type="button" variant="secondary" onClick={() => setEditingDevice(null)} disabled={editSaving}>
                  Cancel
                </Button>
                <Button type="submit" disabled={editSaving}>
                  {editSaving ? "Saving…" : "Save changes"}
                </Button>
              </div>
            </form>
          )}
        </Dialog>

        <ConfirmDeleteDialog
          open={pendingDelete !== null}
          title="Delete device"
          description={
            pendingDelete
              ? `Delete ${pendingDelete.device_code}? This can't be undone. Associated telemetry history and linkages will be cleaned up.`
              : ""
          }
          busy={deleting}
          onConfirm={confirmDelete}
          onClose={() => setPendingDelete(null)}
        />
      </Card>
    </div>
  );
}

/** Complete Dog Management CRUD Tab */
function DogsTab({
  dogs,
  users,
  clinics,
  devices,
  clinicNames,
  onCreated,
  onChanged,
  onDeleted,
  onBulkDeleted,
  onDeviceChanged,
  onToast,
}: {
  dogs: Dog[];
  users: User[];
  clinics: Clinic[];
  devices: Device[];
  clinicNames: Map<string, string>;
  onCreated: (d: Dog) => void;
  onChanged: (d: Dog) => void;
  onDeleted: (id: string, name: string) => void;
  onBulkDeleted: (deletedIds: string[], count: number) => void;
  onDeviceChanged: (dev: Device) => void;
  onToast: (kind: "success" | "error", message: string) => void;
}) {
  const [search, setSearch] = useState("");
  const [clinicFilter, setClinicFilter] = useState<string>("all");

  // Create modal state
  const [addOpen, setAddOpen] = useState(false);
  const [createName, setCreateName] = useState("");
  const [createBreed, setCreateBreed] = useState("");
  const [createSex, setCreateSex] = useState<DogSex>("unknown");
  const [createBirthdate, setCreateBirthdate] = useState("");
  const [createWeight, setCreateWeight] = useState("");
  const [createOwnerId, setCreateOwnerId] = useState("");
  const [createClinicId, setCreateClinicId] = useState("");
  const [createNotes, setCreateNotes] = useState("");
  const [createPhotoFile, setCreatePhotoFile] = useState<File | null>(null);
  const [creating, setCreating] = useState(false);

  // Edit modal state
  const [editingDog, setEditingDog] = useState<Dog | null>(null);
  const [editName, setEditName] = useState("");
  const [editBreed, setEditBreed] = useState("");
  const [editSex, setEditSex] = useState<DogSex>("unknown");
  const [editBirthdate, setEditBirthdate] = useState("");
  const [editWeight, setEditWeight] = useState("");
  const [editOwnerId, setEditOwnerId] = useState("");
  const [editClinicId, setEditClinicId] = useState("");
  const [editNotes, setEditNotes] = useState("");
  const [editPhotoFile, setEditPhotoFile] = useState<File | null>(null);
  const [editSaving, setEditSaving] = useState(false);

  // View modal state
  const [viewingDog, setViewingDog] = useState<Dog | null>(null);
  const [viewingPhotoUrl, setViewingPhotoUrl] = useState<string | null>(null);

  // Delete modal state
  const [pendingDelete, setPendingDelete] = useState<Dog | null>(null);
  const [deleting, setDeleting] = useState(false);

  // Multi-select bulk state
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [bulkDeleteOpen, setBulkDeleteOpen] = useState(false);
  const [bulkDeleting, setBulkDeleting] = useState(false);

  const userMap = useMemo(() => new Map(users.map((u) => [u.id, u.name])), [users]);
  const dogDeviceMap = useMemo(() => {
    const map = new Map<string, Device>();
    devices.forEach((d) => {
      if (d.dog_id) map.set(d.dog_id, d);
    });
    return map;
  }, [devices]);

  const filteredDogs = useMemo(() => {
    return dogs.filter((dog) => {
      if (clinicFilter === "unassigned" && dog.clinic_id) return false;
      if (clinicFilter !== "all" && clinicFilter !== "unassigned" && dog.clinic_id !== clinicFilter) return false;
      if (search.trim() !== "") {
        const query = search.toLowerCase();
        const matchesName = dog.name.toLowerCase().includes(query);
        const matchesBreed = (dog.breed ?? "").toLowerCase().includes(query);
        const ownerName = (userMap.get(dog.owner_user_id) ?? "").toLowerCase();
        const matchesOwner = ownerName.includes(query);
        return matchesName || matchesBreed || matchesOwner;
      }
      return true;
    });
  }, [dogs, clinicFilter, search, userMap]);

  const toggleSelectAll = () => {
    if (selectedIds.size === filteredDogs.length) setSelectedIds(new Set());
    else setSelectedIds(new Set(filteredDogs.map((d) => d.id)));
  };

  const toggleSelect = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  async function handleCreateDog(e: FormEvent) {
    e.preventDefault();
    if (createName.trim() === "" || createOwnerId === "") {
      onToast("error", "Dog Name and Owner are required.");
      return;
    }
    setCreating(true);
    try {
      const newDog = await createDog(supabase, {
        name: createName,
        breed: createBreed,
        sex: createSex,
        birthdate: createBirthdate || null,
        weight_kg: createWeight ? parseFloat(createWeight) : null,
        notes: createNotes,
        owner_user_id: createOwnerId,
        clinic_id: createClinicId === "" ? null : createClinicId,
      });

      // Upload photo if selected
      if (createPhotoFile) {
        try {
          const photoPath = await uploadDogPhoto(supabase, newDog.id, createPhotoFile);
          newDog.photo_path = photoPath;
        } catch (photoErr) {
          console.warn("Photo upload failed:", photoErr);
        }
      }

      onCreated(newDog);
      setAddOpen(false);
      // Reset form
      setCreateName("");
      setCreateBreed("");
      setCreateSex("unknown");
      setCreateBirthdate("");
      setCreateWeight("");
      setCreateOwnerId("");
      setCreateClinicId("");
      setCreateNotes("");
      setCreatePhotoFile(null);
    } catch (err) {
      onToast("error", friendlyError(err, "create dog profile"));
    } finally {
      setCreating(false);
    }
  }

  function startEdit(dog: Dog) {
    setEditingDog(dog);
    setEditName(dog.name);
    setEditBreed(dog.breed ?? "");
    setEditSex(dog.sex ?? "unknown");
    setEditBirthdate(dog.birthdate ?? "");
    setEditWeight(dog.weight_kg != null ? String(dog.weight_kg) : "");
    setEditOwnerId(dog.owner_user_id);
    setEditClinicId(dog.clinic_id ?? "");
    setEditNotes(dog.notes ?? "");
    setEditPhotoFile(null);
  }

  async function saveEditDog(e: FormEvent) {
    e.preventDefault();
    if (!editingDog || editName.trim() === "") return;
    setEditSaving(true);
    try {
      let photoPath = editingDog.photo_path;
      if (editPhotoFile) {
        photoPath = await uploadDogPhoto(supabase, editingDog.id, editPhotoFile);
      }

      const updated = await updateDog(supabase, editingDog.id, {
        name: editName,
        breed: editBreed,
        sex: editSex,
        birthdate: editBirthdate || null,
        weight_kg: editWeight ? parseFloat(editWeight) : null,
        owner_user_id: editOwnerId,
        clinic_id: editClinicId === "" ? null : editClinicId,
        notes: editNotes,
        photo_path: photoPath,
      });

      onChanged(updated);
      setEditingDog(null);
    } catch (err) {
      onToast("error", friendlyError(err, "update dog profile"));
    } finally {
      setEditSaving(false);
    }
  }

  async function confirmSingleDelete() {
    if (!pendingDelete) return;
    setDeleting(true);
    try {
      await deleteDog(supabase, pendingDelete.id);
      onDeleted(pendingDelete.id, pendingDelete.name);
      setPendingDelete(null);
    } catch (err) {
      onToast("error", friendlyError(err, "delete dog"));
    } finally {
      setDeleting(false);
    }
  }

  async function handleBulkDelete() {
    const ids = Array.from(selectedIds);
    if (ids.length === 0) return;
    setBulkDeleting(true);
    try {
      const res = await bulkDeleteDogs(supabase, ids);
      if (res.success.length > 0) {
        onBulkDeleted(res.success, res.success.length);
        setSelectedIds(new Set());
        setBulkDeleteOpen(false);
      }
      if (res.failed.length > 0) {
        onToast("error", `Failed to delete ${res.failed.length} dog(s): ${res.failed[0].error}`);
      }
    } catch (err) {
      onToast("error", friendlyError(err, "bulk delete dogs"));
    } finally {
      setBulkDeleting(false);
    }
  }

  async function handleQuickClinicAssign(dog: Dog, clinicId: string | null) {
    try {
      const updated = await updateDogClinic(supabase, dog.id, clinicId);
      onChanged(updated);
    } catch (err) {
      onToast("error", friendlyError(err, "update clinic assignment"));
    }
  }

  async function handleQuickDevicePair(dog: Dog, newDeviceId: string | null) {
    try {
      const currentPairedDevice = dogDeviceMap.get(dog.id);
      // If dog currently had a device, unpair it
      if (currentPairedDevice && currentPairedDevice.id !== newDeviceId) {
        const unpairRes = await updateDevice(supabase, currentPairedDevice.id, { dog_id: null });
        onDeviceChanged(unpairRes);
      }
      // If a new device is picked, pair it
      if (newDeviceId) {
        const pairRes = await updateDevice(supabase, newDeviceId, { dog_id: dog.id });
        onDeviceChanged(pairRes);
        onToast("success", `Paired ${pairRes.device_code} to ${dog.name}`);
      } else {
        onToast("success", `Unpaired collar from ${dog.name}`);
      }
    } catch (err) {
      onToast("error", friendlyError(err, "update device pairing"));
    }
  }

  useEffect(() => {
    if (!viewingDog?.photo_path) {
      setViewingPhotoUrl(null);
      return;
    }
    getMediaSignedUrl(supabase, viewingDog.photo_path)
      .then(setViewingPhotoUrl)
      .catch(() => setViewingPhotoUrl(null));
  }, [viewingDog]);

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-4">
        <div>
          <CardTitle>Dog Patients &amp; Clinic Linkages</CardTitle>
          <CardDescription>
            Full patient management: register dogs, assign owners &amp; partner clinics, pair collars, and manage clinical records.
          </CardDescription>
        </div>
        <div className="flex items-center gap-2">
          {selectedIds.size > 0 && (
            <Button
              variant="destructive"
              size="sm"
              onClick={() => setBulkDeleteOpen(true)}
              className="font-bold shadow-xs flex items-center gap-1.5"
            >
              <Trash2 size={13} />
              <span>Bulk Delete Dogs ({selectedIds.size})</span>
            </Button>
          )}
          <Button type="button" onClick={() => setAddOpen(true)}>
            <Plus size={14} /> Register Dog
          </Button>
        </div>
      </CardHeader>
      <CardContent className="flex flex-col gap-5">
        {/* Search & Filter Toolbar */}
        <div className="flex flex-wrap items-center justify-between gap-3 bg-surface-alt p-3 rounded-lg border border-hairline">
          <div className="flex items-center gap-2 flex-1 min-w-[240px]">
            <Search size={15} className="text-ink-muted shrink-0" />
            <Input
              placeholder="Search by dog name, breed, or owner…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="h-9 text-xs bg-surface"
            />
          </div>

          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-ink-muted">Clinic Filter:</span>
            <Select
              className="h-9 text-xs w-48 bg-surface"
              value={clinicFilter}
              onChange={(e) => setClinicFilter(e.target.value)}
            >
              <option value="all">All Clinics ({dogs.length})</option>
              <option value="unassigned">Unassigned Only</option>
              {clinics.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
          </div>
        </div>

        {/* Dogs Table */}
        <Table>
          <THead>
            <Tr className="border-t-0">
              <Th className="w-10 text-center">
                <input
                  type="checkbox"
                  aria-label="Select all dogs"
                  checked={selectedIds.size === filteredDogs.length && filteredDogs.length > 0}
                  onChange={toggleSelectAll}
                  className="accent-[#0088D6] rounded h-4 w-4 cursor-pointer"
                />
              </Th>
              <Th>Patient</Th>
              <Th>Owner</Th>
              <Th>Clinic Linkage</Th>
              <Th>Paired Collar</Th>
              <Th>Actions</Th>
            </Tr>
          </THead>
          <TBody>
            {filteredDogs.length === 0 ? (
              <Tr>
                <Td colSpan={6} className="text-center py-8">
                  <EmptyState>No dog patients found matching your search criteria 🐾</EmptyState>
                </Td>
              </Tr>
            ) : (
              filteredDogs.map((dog) => {
                const isSelected = selectedIds.has(dog.id);
                const pairedDevice = dogDeviceMap.get(dog.id);
                const ownerName = userMap.get(dog.owner_user_id) ?? "—";

                return (
                  <Tr key={dog.id} className={isSelected ? "bg-brand-soft/40" : undefined}>
                    <Td className="text-center">
                      <input
                        type="checkbox"
                        aria-label={`Select ${dog.name}`}
                        checked={isSelected}
                        onChange={() => toggleSelect(dog.id)}
                        className="accent-[#0088D6] rounded h-4 w-4 cursor-pointer"
                      />
                    </Td>

                    <Td className="font-semibold">
                      <div className="flex items-center gap-3">
                        <div
                          className={cn(
                            "flex h-9 w-9 shrink-0 items-center justify-center rounded-lg text-lg select-none shadow-2xs",
                            dogTint(dog.id),
                          )}
                        >
                          🐶
                        </div>
                        <div className="flex flex-col min-w-0">
                          <Link
                            to={`/dogs/${dog.id}`}
                            className="font-bold text-ink hover:text-brand-strong transition-colors truncate"
                          >
                            {dog.name}
                          </Link>
                          <span className="text-xs text-ink-muted truncate">
                            {dog.breed ?? "Unknown breed"} • {dog.sex ?? "—"}
                          </span>
                        </div>
                      </div>
                    </Td>

                    <Td className="text-sm text-ink-muted">
                      <div className="flex items-center gap-1.5">
                        <UsersIcon size={13} className="text-ink-muted shrink-0" />
                        <span className="font-medium text-ink truncate">{ownerName}</span>
                      </div>
                    </Td>

                    <Td>
                      <Select
                        aria-label={`Clinic for ${dog.name}`}
                        className="h-8.5 text-xs w-44 bg-surface"
                        value={dog.clinic_id ?? ""}
                        onChange={(e) =>
                          handleQuickClinicAssign(dog, e.target.value === "" ? null : e.target.value)
                        }
                      >
                        <option value="">— Unassigned —</option>
                        {clinics.map((c) => (
                          <option key={c.id} value={c.id}>
                            {clinicNames.get(c.id) ?? c.name}
                          </option>
                        ))}
                      </Select>
                    </Td>

                    <Td>
                      <Select
                        aria-label={`Device for ${dog.name}`}
                        className="h-8.5 text-xs w-44 bg-surface"
                        value={pairedDevice?.id ?? ""}
                        onChange={(e) =>
                          handleQuickDevicePair(dog, e.target.value === "" ? null : e.target.value)
                        }
                      >
                        <option value="">— No collar paired —</option>
                        {/* Currently paired device */}
                        {pairedDevice && (
                          <option value={pairedDevice.id}>
                            {pairedDevice.device_code} ({pairedDevice.status})
                          </option>
                        )}
                        {/* Unpaired available devices */}
                        {devices
                          .filter((dev) => !dev.dog_id || dev.dog_id === dog.id)
                          .filter((dev) => dev.id !== pairedDevice?.id)
                          .map((dev) => (
                            <option key={dev.id} value={dev.id}>
                              {dev.device_code} ({dev.status})
                            </option>
                          ))}
                      </Select>
                    </Td>

                    <Td>
                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          aria-label={`View ${dog.name}`}
                          title="View Patient Details"
                          onClick={() => setViewingDog(dog)}
                          className="flex h-8 w-8 items-center justify-center rounded-md bg-surface-alt text-ink-muted transition-colors duration-fast hover:bg-brand-soft hover:text-brand-strong"
                        >
                          <Eye size={15} />
                        </button>

                        <button
                          type="button"
                          aria-label={`Edit ${dog.name}`}
                          title="Edit Patient Profile"
                          onClick={() => startEdit(dog)}
                          className="flex h-8 w-8 items-center justify-center rounded-md bg-brand-soft text-brand-strong transition-colors duration-fast hover:bg-brand hover:text-white"
                        >
                          <Pencil size={15} />
                        </button>

                        <button
                          type="button"
                          aria-label={`Delete ${dog.name}`}
                          title="Delete Patient Record"
                          onClick={() => setPendingDelete(dog)}
                          className="flex h-8 w-8 items-center justify-center rounded-md bg-high-soft text-high-fg transition-colors duration-fast hover:bg-high hover:text-white"
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>
                    </Td>
                  </Tr>
                );
              })
            )}
          </TBody>
        </Table>
      </CardContent>

      {/* Bulk Delete Dogs Modal */}
      <ConfirmDeleteDialog
        open={bulkDeleteOpen}
        title={`Bulk Delete Dogs (${selectedIds.size})`}
        description={`Are you sure you want to permanently delete these ${selectedIds.size} dog patient profiles? This action cannot be undone.`}
        busy={bulkDeleting}
        onConfirm={handleBulkDelete}
        onClose={() => setBulkDeleteOpen(false)}
      />

      {/* Register Dog Modal */}
      <Dialog open={addOpen} onClose={() => setAddOpen(false)} title="Register Dog Patient">
        <form onSubmit={handleCreateDog} className="flex flex-col gap-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1">
              <Label htmlFor="create-dog-name">Dog Name *</Label>
              <Input
                id="create-dog-name"
                required
                placeholder="e.g. Mochi"
                value={createName}
                onChange={(e) => setCreateName(e.target.value)}
              />
            </div>

            <div className="flex flex-col gap-1">
              <Label htmlFor="create-dog-breed">Breed</Label>
              <Input
                id="create-dog-breed"
                placeholder="e.g. Golden Retriever"
                value={createBreed}
                onChange={(e) => setCreateBreed(e.target.value)}
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="flex flex-col gap-1">
              <Label htmlFor="create-dog-sex">Sex</Label>
              <Select
                id="create-dog-sex"
                className="h-10 w-full"
                value={createSex}
                onChange={(e) => setCreateSex(e.target.value as DogSex)}
              >
                <option value="unknown">Unknown</option>
                <option value="male">Male</option>
                <option value="female">Female</option>
              </Select>
            </div>

            <div className="flex flex-col gap-1">
              <Label htmlFor="create-dog-birthdate">Birthdate</Label>
              <Input
                id="create-dog-birthdate"
                type="date"
                value={createBirthdate}
                onChange={(e) => setCreateBirthdate(e.target.value)}
              />
            </div>

            <div className="flex flex-col gap-1">
              <Label htmlFor="create-dog-weight">Weight (kg)</Label>
              <Input
                id="create-dog-weight"
                type="number"
                step="0.1"
                placeholder="e.g. 14.5"
                value={createWeight}
                onChange={(e) => setCreateWeight(e.target.value)}
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1">
              <Label htmlFor="create-dog-owner">Owner Account *</Label>
              <Select
                id="create-dog-owner"
                required
                className="h-10 w-full"
                value={createOwnerId}
                onChange={(e) => setCreateOwnerId(e.target.value)}
              >
                <option value="">— Select Owner —</option>
                {users.map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.name} ({u.email})
                  </option>
                ))}
              </Select>
            </div>

            <div className="flex flex-col gap-1">
              <Label htmlFor="create-dog-clinic">Partner Clinic</Label>
              <Select
                id="create-dog-clinic"
                className="h-10 w-full"
                value={createClinicId}
                onChange={(e) => setCreateClinicId(e.target.value)}
              >
                <option value="">— Unassigned (Home only) —</option>
                {clinics.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </Select>
            </div>
          </div>

          <div className="flex flex-col gap-1">
            <Label htmlFor="create-dog-notes">Medical &amp; Behavioral Notes</Label>
            <Input
              id="create-dog-notes"
              placeholder="e.g. Sensitive to loud thunder, recovering from ear infection"
              value={createNotes}
              onChange={(e) => setCreateNotes(e.target.value)}
            />
          </div>

          <div className="flex flex-col gap-1">
            <Label htmlFor="create-dog-photo">Profile Photo (Optional)</Label>
            <input
              id="create-dog-photo"
              type="file"
              accept="image/*"
              className="text-xs file:mr-2 file:rounded-md file:border-0 file:bg-brand-soft file:px-3 file:py-1 file:text-xs file:font-semibold file:text-brand-strong"
              onChange={(e) => setCreatePhotoFile(e.target.files?.[0] ?? null)}
            />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button type="button" variant="secondary" onClick={() => setAddOpen(false)} disabled={creating}>
              Cancel
            </Button>
            <Button type="submit" disabled={creating || createName.trim() === "" || createOwnerId === ""}>
              {creating ? "Registering…" : "Register Dog"}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Edit Dog Modal */}
      <Dialog open={editingDog !== null} onClose={() => setEditingDog(null)} title="Edit Dog Patient">
        {editingDog && (
          <form onSubmit={saveEditDog} className="flex flex-col gap-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-name">Dog Name *</Label>
                <Input
                  id="edit-dog-name"
                  required
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                />
              </div>

              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-breed">Breed</Label>
                <Input
                  id="edit-dog-breed"
                  value={editBreed}
                  onChange={(e) => setEditBreed(e.target.value)}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-sex">Sex</Label>
                <Select
                  id="edit-dog-sex"
                  className="h-10 w-full"
                  value={editSex}
                  onChange={(e) => setEditSex(e.target.value as DogSex)}
                >
                  <option value="unknown">Unknown</option>
                  <option value="male">Male</option>
                  <option value="female">Female</option>
                </Select>
              </div>

              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-birthdate">Birthdate</Label>
                <Input
                  id="edit-dog-birthdate"
                  type="date"
                  value={editBirthdate}
                  onChange={(e) => setEditBirthdate(e.target.value)}
                />
              </div>

              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-weight">Weight (kg)</Label>
                <Input
                  id="edit-dog-weight"
                  type="number"
                  step="0.1"
                  value={editWeight}
                  onChange={(e) => setEditWeight(e.target.value)}
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-owner">Owner Account *</Label>
                <Select
                  id="edit-dog-owner"
                  required
                  className="h-10 w-full"
                  value={editOwnerId}
                  onChange={(e) => setEditOwnerId(e.target.value)}
                >
                  {users.map((u) => (
                    <option key={u.id} value={u.id}>
                      {u.name} ({u.email})
                    </option>
                  ))}
                </Select>
              </div>

              <div className="flex flex-col gap-1">
                <Label htmlFor="edit-dog-clinic">Partner Clinic</Label>
                <Select
                  id="edit-dog-clinic"
                  className="h-10 w-full"
                  value={editClinicId}
                  onChange={(e) => setEditClinicId(e.target.value)}
                >
                  <option value="">— Unassigned (Home only) —</option>
                  {clinics.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </Select>
              </div>
            </div>

            <div className="flex flex-col gap-1">
              <Label htmlFor="edit-dog-notes">Medical &amp; Behavioral Notes</Label>
              <Input
                id="edit-dog-notes"
                value={editNotes}
                onChange={(e) => setEditNotes(e.target.value)}
              />
            </div>

            <div className="flex flex-col gap-1">
              <Label htmlFor="edit-dog-photo">Replace Photo (Optional)</Label>
              <input
                id="edit-dog-photo"
                type="file"
                accept="image/*"
                className="text-xs file:mr-2 file:rounded-md file:border-0 file:bg-brand-soft file:px-3 file:py-1 file:text-xs file:font-semibold file:text-brand-strong"
                onChange={(e) => setEditPhotoFile(e.target.files?.[0] ?? null)}
              />
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="secondary" onClick={() => setEditingDog(null)} disabled={editSaving}>
                Cancel
              </Button>
              <Button type="submit" disabled={editSaving || editName.trim() === "" || editOwnerId === ""}>
                {editSaving ? "Saving…" : "Save Changes"}
              </Button>
            </div>
          </form>
        )}
      </Dialog>

      {/* View Dog Details Dialog */}
      <Dialog
        open={viewingDog !== null}
        onClose={() => setViewingDog(null)}
        title={viewingDog ? `Patient Profile — ${viewingDog.name}` : "Patient Details"}
      >
        {viewingDog && (
          <div className="flex flex-col gap-4 text-sm">
            <div className="flex items-center gap-4 border-b border-hairline pb-4">
              <div className="relative h-16 w-16 shrink-0 overflow-hidden rounded-xl bg-surface-alt border border-hairline">
                {viewingPhotoUrl ? (
                  <img
                    src={viewingPhotoUrl}
                    alt={viewingDog.name}
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <div
                    className={cn(
                      "flex h-full w-full items-center justify-center text-3xl select-none",
                      dogTint(viewingDog.id),
                    )}
                  >
                    🐶
                  </div>
                )}
              </div>
              <div className="flex flex-col">
                <h3 className="text-lg font-bold text-ink m-0">{viewingDog.name}</h3>
                <span className="text-xs text-ink-muted">
                  {viewingDog.breed ?? "Unknown breed"} • {viewingDog.sex ?? "Unknown sex"}
                </span>
                <span className="text-xs text-ink-muted mt-0.5">
                  Weight: {viewingDog.weight_kg ? `${viewingDog.weight_kg} kg` : "—"}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="flex flex-col">
                <span className="text-xs font-semibold text-ink-muted">Owner</span>
                <span className="font-medium text-ink">{userMap.get(viewingDog.owner_user_id) ?? "—"}</span>
              </div>

              <div className="flex flex-col">
                <span className="text-xs font-semibold text-ink-muted">Clinic</span>
                <span className="font-medium text-ink">
                  {viewingDog.clinic_id ? (clinicNames.get(viewingDog.clinic_id) ?? "—") : "Unassigned"}
                </span>
              </div>

              <div className="flex flex-col">
                <span className="text-xs font-semibold text-ink-muted">Paired Collar</span>
                <span className="font-medium text-ink">
                  {dogDeviceMap.get(viewingDog.id)?.device_code ?? "None"}
                </span>
              </div>

              <div className="flex flex-col">
                <span className="text-xs font-semibold text-ink-muted">Registered Date</span>
                <span className="text-xs text-ink-muted">{formatPhilippineTime(viewingDog.created_at)}</span>
              </div>
            </div>

            {viewingDog.notes && (
              <div className="rounded-lg bg-surface-alt p-3 border border-hairline text-xs text-ink-muted">
                <span className="font-bold text-ink block mb-1">Clinical Notes:</span>
                {viewingDog.notes}
              </div>
            )}

            <div className="flex justify-between items-center pt-2">
              <Link
                to={`/dogs/${viewingDog.id}`}
                className="inline-flex items-center gap-1.5 text-xs font-bold text-brand hover:underline"
              >
                <span>Open Full Clinical Chart</span>
                <ArrowRight size={13} />
              </Link>
              <div className="flex gap-2">
                <Button variant="secondary" onClick={() => setViewingDog(null)}>
                  Close
                </Button>
                <Button
                  onClick={() => {
                    const d = viewingDog;
                    setViewingDog(null);
                    startEdit(d);
                  }}
                >
                  <Pencil size={14} /> Edit Profile
                </Button>
              </div>
            </div>
          </div>
        )}
      </Dialog>

      {/* Delete Dog Dialog */}
      <ConfirmDeleteDialog
        open={pendingDelete !== null}
        title="Delete Patient Record"
        description={
          pendingDelete
            ? `Delete patient "${pendingDelete.name}"? This will permanently remove their profile. Telemetry history attached to active devices should be unassigned first.`
            : ""
        }
        busy={deleting}
        onConfirm={confirmSingleDelete}
        onClose={() => setPendingDelete(null)}
      />
    </Card>
  );
}

/** Audit Logs Tab */
function AuditLogsTab() {
  const [logs, setLogs] = useState<AuditLogRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [surfaceFilter, setSurfaceFilter] = useState("all");
  const [roleFilter, setRoleFilter] = useState("all");
  const [severityFilter, setSeverityFilter] = useState("all");
  const [selectedLog, setSelectedLog] = useState<AuditLogRecord | null>(null);

  const loadLogs = useCallback(async () => {
    setLoading(true);
    const data = await fetchAuditLogs({
      surface: surfaceFilter,
      role: roleFilter,
      severity: severityFilter,
      search,
    });
    setLogs(data);
    setLoading(false);
  }, [surfaceFilter, roleFilter, severityFilter, search]);

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  const handleExportCSV = () => {
    if (logs.length === 0) return;
    const headers = [
      "Timestamp",
      "Surface",
      "Actor Email",
      "Actor Role",
      "Action",
      "Target Resource",
      "Target ID",
      "Severity",
    ];
    const rows = logs.map((l) => [
      new Date(l.created_at).toISOString(),
      l.surface,
      l.actor_email,
      l.actor_role,
      l.action,
      l.target_resource,
      l.target_id ?? "",
      l.severity,
    ]);

    const csvContent =
      "data:text/csv;charset=utf-8," +
      [headers.join(","), ...rows.map((e) => e.map((val) => `"${val}"`).join(","))].join("\n");
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `furfeel_audit_logs_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <div>
          <CardTitle>System Audit Logs</CardTitle>
          <CardDescription>Immutable record of critical administrative and clinical actions</CardDescription>
        </div>
        <div className="flex gap-2">
          <Button variant="secondary" size="sm" onClick={loadLogs} disabled={loading}>
            <RefreshCw size={14} className={loading ? "animate-spin" : ""} />
            Refresh
          </Button>
          <Button variant="secondary" size="sm" onClick={handleExportCSV} disabled={logs.length === 0}>
            <Download size={14} />
            Export CSV
          </Button>
        </div>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {/* Filters */}
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
          <Input
            placeholder="Search action or email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <Select value={surfaceFilter} onChange={(e) => setSurfaceFilter(e.target.value)}>
            <option value="all">All Surfaces</option>
            <option value="dashboard">Dashboard</option>
            <option value="mobile">Mobile App</option>
            <option value="edge_function">Edge Functions</option>
            <option value="database">Database</option>
          </Select>
          <Select value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)}>
            <option value="all">All Roles</option>
            <option value="admin">Admin</option>
            <option value="veterinarian">Veterinarian</option>
            <option value="vet_staff">Vet Staff</option>
            <option value="owner">Dog Owner</option>
            <option value="system">System</option>
          </Select>
          <Select value={severityFilter} onChange={(e) => setSeverityFilter(e.target.value)}>
            <option value="all">All Severities</option>
            <option value="info">Info</option>
            <option value="warning">Warning</option>
            <option value="critical">Critical</option>
          </Select>
        </div>

        {/* Table */}
        {loading ? (
          <CardSkeleton lines={5} />
        ) : logs.length === 0 ? (
          <EmptyState>No audit records match the selected filters.</EmptyState>
        ) : (
          <Table>
            <THead>
              <Tr>
                <Th>Time</Th>
                <Th>Actor</Th>
                <Th>Action</Th>
                <Th>Target</Th>
                <Th>Surface</Th>
                <Th>Severity</Th>
                <Th>Details</Th>
              </Tr>
            </THead>
            <TBody>
              {logs.map((log) => (
                <Tr key={log.id}>
                  <Td className="text-xs text-ink-muted whitespace-nowrap">
                    {formatPhilippineTime(log.created_at)}
                  </Td>
                  <Td>
                    <div className="font-medium text-xs text-ink">{log.actor_email}</div>
                    <div className="text-[10px] text-ink-muted uppercase">{log.actor_role}</div>
                  </Td>
                  <Td className="font-mono text-xs font-semibold">{log.action}</Td>
                  <Td className="text-xs">
                    <span className="font-medium text-ink">{log.target_resource}</span>
                    {log.target_id && (
                      <span className="text-[10px] text-ink-muted block truncate max-w-[120px]">
                        {log.target_id}
                      </span>
                    )}
                  </Td>
                  <Td className="text-xs capitalize">{log.surface}</Td>
                  <Td>
                    <span
                      className={cn(
                        "rounded-full px-2 py-0.5 text-[10px] font-bold uppercase",
                        log.severity === "critical"
                          ? "bg-red-100 text-red-800"
                          : log.severity === "warning"
                            ? "bg-amber-100 text-amber-800"
                            : "bg-slate-100 text-slate-800",
                      )}
                    >
                      {log.severity}
                    </span>
                  </Td>
                  <Td>
                    <Button variant="ghost" size="sm" onClick={() => setSelectedLog(log)}>
                      <Eye size={14} />
                    </Button>
                  </Td>
                </Tr>
              ))}
            </TBody>
          </Table>
        )}
      </CardContent>

      {/* Details Dialog */}
      <Dialog
        open={selectedLog !== null}
        onClose={() => setSelectedLog(null)}
        title="Audit Log Details"
      >
        {selectedLog && (
          <div className="flex flex-col gap-3 text-xs">
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Action</span>
              <span className="col-span-2 font-mono font-bold text-ink">{selectedLog.action}</span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Timestamp</span>
              <span className="col-span-2 text-ink">{formatPhilippineTime(selectedLog.created_at)}</span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Actor</span>
              <span className="col-span-2 text-ink">
                {selectedLog.actor_email} ({selectedLog.actor_role})
              </span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">Target</span>
              <span className="col-span-2 text-ink">
                {selectedLog.target_resource} ({selectedLog.target_id ?? "N/A"})
              </span>
            </div>
            <div className="grid grid-cols-3 gap-1 border-b border-hairline pb-2">
              <span className="font-semibold text-ink-muted">IP Address</span>
              <span className="col-span-2 font-mono text-ink">
                {((selectedLog.details as Record<string, unknown>)?.ip_address as string) ?? "Web Dashboard"}
              </span>
            </div>
            <div>
              <span className="font-semibold text-ink-muted block mb-1">Payload / Details:</span>
              <pre className="max-h-48 overflow-auto rounded bg-surface-alt p-2 font-mono text-[11px] border border-hairline text-ink">
                {JSON.stringify(selectedLog.details, null, 2)}
              </pre>
            </div>
            <div className="flex justify-end pt-2">
              <Button variant="secondary" onClick={() => setSelectedLog(null)}>
                Close
              </Button>
            </div>
          </div>
        )}
      </Dialog>
    </Card>
  );
}
