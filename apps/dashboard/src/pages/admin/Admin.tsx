import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";
import { Navigate, useParams, useSearchParams } from "react-router-dom";
import {
  Activity,
  Bell,
  Building2,
  Dog as DogIcon,
  Eye,
  Pencil,
  Plus,
  Trash2,
  Users as UsersIcon,
  Wifi,
  WifiOff,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  createClinic,
  createUserAccount,
  deleteClinic,
  deleteDevice,
  deleteUserAccount,
  fetchAllDevices,
  fetchAllDogs,
  fetchAllUsers,
  fetchClinics,
  fetchSystemHealth,
  registerDevice,
  updateClinic,
  updateDevice,
  updateDogClinic,
  updateUserRoleClinic,
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
} from "../../lib/queries.ts";
import { AlertCard } from "../../components/AlertCard.tsx";
import { formatPhilippineTime } from "../../lib/time.ts";
import type {
  Alert,
  Clinic,
  Device,
  DeviceStatus,
  Dog,
  User,
  UserRole,
} from "../../../../../packages/shared/types/index.ts";

const ROLES: UserRole[] = ["owner", "vet_staff", "veterinarian", "admin"];
const DEVICE_STATUSES: DeviceStatus[] = ["active", "inactive", "offline", "maintenance"];
type Tab = "users" | "clinics" | "devices" | "health";
const TABS: Tab[] = ["users", "clinics", "devices", "health"];

/** Shared destructive-action confirmation (docs/19 dialog primitive). Delete
 * is the one Admin action that can't be undone, so every delete flow in this
 * page routes through this instead of firing on a single click. */
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
      <p className="m-0 mb-4 text-sm text-ink-muted">{description}</p>
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

/** Admin (docs/05 §4): manage users (role + clinic), clinics, and devices.
 * The page is offered to the admin role only as UX; the users_update_admin /
 * clinics_admin_manage / devices_admin_all RLS policies are the actual gate. */
export function Admin() {
  const { tab: tabParam } = useParams<{ tab: string }>();
  const { role, loading: roleLoading } = useCurrentRole();
  const { session } = useAuth();
  const toast = useToast();
  const [users, setUsers] = useState<User[]>([]);
  const [clinics, setClinics] = useState<Clinic[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const [userRows, clinicRows, deviceRows, dogRows] = await Promise.all([
        fetchAllUsers(supabase),
        fetchClinics(supabase),
        fetchAllDevices(supabase),
        fetchAllDogs(supabase),
      ]);
      setUsers(userRows);
      setClinics(clinicRows);
      setDevices(deviceRows);
      setDogs(dogRows);
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
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );
  if (!tabParam || !TABS.includes(tabParam as Tab)) return <Navigate to="/admin/users" replace />;
  const tab = tabParam as Tab;

  return (
    <div className="flex flex-col gap-5">
      <h1 className="m-0 text-2xl font-bold capitalize text-ink">Admin — {tab}</h1>

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
          onError={(m) => toast("error", m)}
        />
      )}
      {tab === "devices" && (
        <DevicesTab
          devices={devices}
          dogs={dogs}
          clinics={clinics}
          dogNames={dogNames}
          clinicNames={clinicNames}
          onChanged={(d) => setDevices((prev) => prev.map((x) => (x.id === d.id ? d : x)))}
          onRegistered={(d) => setDevices((prev) => [...prev, d])}
          onDeleted={(id) => setDevices((prev) => prev.filter((x) => x.id !== id))}
          onDogClinicChanged={(dog) =>
            setDogs((prev) => prev.map((x) => (x.id === dog.id ? dog : x)))
          }
          onToast={toast}
        />
      )}
      {tab === "health" && (
        <HealthTab users={users} clinics={clinics} devices={devices} dogs={dogs} />
      )}
    </div>
  );
}

/** System Health (docs/03 admin permission "view system health"). Read-only:
 * fleet + entity counts come from the already-loaded admin data; telemetry and
 * alert volume are fetched here. */
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
  const offline = devices.filter((d) => d.status === "offline").length;

  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );
  if (!health) return <CardSkeleton lines={4} />;

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap gap-4">
        <Kpi label="Devices online" value={String(online)} icon={<Wifi size={22} />} tone="positive" />
        <Kpi
          label="Devices offline"
          value={String(offline)}
          icon={<WifiOff size={22} />}
          tone="attention"
          attention={offline > 0}
        />
        <Kpi
          label="Open alerts"
          value={String(health.open_alerts)}
          icon={<Bell size={22} />}
          tone="attention"
          attention={health.open_alerts > 0}
        />
      </div>
      <div className="flex flex-wrap gap-4">
        <Kpi label="Readings, last hour" value={health.telemetry_last_hour.toLocaleString()} icon={<Activity size={22} />} />
        <Kpi label="Readings, last 24 h" value={health.telemetry_last_24h.toLocaleString()} icon={<Activity size={22} />} />
      </div>
      <div className="flex flex-wrap gap-4">
        <Kpi label="Users" value={String(users.length)} icon={<UsersIcon size={22} />} />
        <Kpi label="Clinics" value={String(clinics.length)} icon={<Building2 size={22} />} />
        <Kpi label="Dogs" value={String(dogs.length)} icon={<DogIcon size={22} />} />
      </div>
      <p className="m-0 text-xs text-ink-muted">
        Last telemetry received:{" "}
        {health.last_telemetry_at ? formatPhilippineTime(health.last_telemetry_at) : "never"}
        {" · "}Device fleet: {devices.length} registered (
        {devices.length - online - offline} inactive/maintenance)
      </p>

      {/* System Alerts Triage Card for Admins */}
      <Card>
        <CardHeader>
          <CardTitle>System &amp; Hardware Alerts</CardTitle>
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

function UsersTab({
  users,
  clinics,
  currentUserId,
  onChanged,
  onCreated,
  onDeleted,
  onError,
}: {
  users: User[];
  clinics: Clinic[];
  currentUserId: string | null;
  onChanged: (u: User) => void;
  onCreated: (u: User) => void;
  onDeleted: (id: string, name: string) => void;
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
  const [deleting, setDeleting] = useState(false);

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

  async function confirmDelete() {
    if (!pendingDelete) return;
    setDeleting(true);
    try {
      await deleteUserAccount(supabase, pendingDelete.id);
      onDeleted(pendingDelete.id, pendingDelete.name);
      setPendingDelete(null);
    } catch (err) {
      onError(friendlyError(err, "delete the user"));
    } finally {
      setDeleting(false);
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
            Manage accounts, view details, assign roles and clinics. Accounts created here can sign in
            right away — no email confirmation needed.
          </CardDescription>
        </div>
        <Button type="button" onClick={() => setAddOpen(true)}>
          <Plus size={14} /> Add user
        </Button>
      </CardHeader>
      <CardContent className="flex flex-col gap-5">
        <Table>
          <THead>
            <Tr className="border-t-0">
              <Th>Name</Th>
              <Th>Email</Th>
              <Th>Role</Th>
              <Th>Clinic</Th>
              <Th>Actions</Th>
            </Tr>
          </THead>
          <TBody>
            {filteredUsers.map((u) => (
              <Tr key={u.id}>
                <Td className="font-semibold">{u.name}</Td>
                <Td className="text-ink-muted">{u.email}</Td>
                <Td>
                  <span className={cn("inline-flex items-center rounded-pill px-2.5 py-0.5 text-xs capitalize", ROLE_BADGE_STYLE[u.role])}>
                    {u.role.replace("_", " ")}
                  </span>
                </Td>
                <Td className="text-ink-muted">
                  {u.clinic_id ? (clinicNames.get(u.clinic_id) ?? "— none —") : "— none —"}
                </Td>
                <Td>
                  <div className="flex items-center gap-2">
                    {/* View Button - Neutral Box */}
                    <button
                      type="button"
                      aria-label={`View details for ${u.name}`}
                      title="View User Details"
                      onClick={() => setViewingUser(u)}
                      className="flex h-8 w-8 items-center justify-center rounded-md bg-surface-alt text-ink-muted transition-colors duration-fast hover:bg-brand-soft hover:text-brand-strong"
                    >
                      <Eye size={15} />
                    </button>

                    {/* Edit Button - Soft Blue Box */}
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

                    {/* Delete Button - Soft Red Box */}
                    {u.id !== currentUserId ? (
                      <button
                        type="button"
                        aria-label={`Delete ${u.name}`}
                        title="Delete User Account"
                        onClick={() => setPendingDelete(u)}
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
            ))}
          </TBody>
        </Table>
      </CardContent>

      {/* Add User Dialog */}
      <Dialog open={addOpen} onClose={() => setAddOpen(false)} title="Add user">
        <form className="flex flex-col gap-3" onSubmit={submit}>
          <div className="flex flex-col gap-1">
            <Label htmlFor="user-name">Name</Label>
            <Input id="user-name" value={name} onChange={(e) => setName(e.target.value)} required />
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="user-email">Email</Label>
            <Input
              id="user-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="user-password">Temporary password</Label>
            <Input
              id="user-password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              minLength={6}
              required
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
              {ROLES.map((r) => (
                <option key={r} value={r}>
                  {r}
                </option>
              ))}
            </Select>
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="user-clinic">Clinic</Label>
            <Select
              id="user-clinic"
              className="h-10 w-full"
              value={newClinicId}
              onChange={(e) => setNewClinicId(e.target.value)}
            >
              <option value="">— none —</option>
              {clinics.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
          </div>
          <div className="flex justify-end gap-2">
            <Button type="button" variant="secondary" onClick={() => setAddOpen(false)} disabled={saving}>
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={saving || name.trim() === "" || email.trim() === "" || password.length < 6}
            >
              {saving ? "Adding…" : "Add user"}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* View User Details Dialog */}
      <Dialog open={viewingUser !== null} onClose={() => setViewingUser(null)} title="User details">
        {viewingUser && (
          <div className="flex flex-col gap-4 py-1">
            <div className="flex flex-col gap-1 border-b border-hairline pb-3">
              <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Account Name</span>
              <span className="text-base font-bold text-ink">{viewingUser.name}</span>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="flex flex-col gap-1">
                <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Email</span>
                <span className="text-sm font-medium text-ink">{viewingUser.email}</span>
              </div>

              <div className="flex flex-col gap-1">
                <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Role</span>
                <div>
                  <span className={cn("inline-flex items-center rounded-pill px-2.5 py-0.5 text-xs capitalize", ROLE_BADGE_STYLE[viewingUser.role])}>
                    {viewingUser.role.replace("_", " ")}
                  </span>
                </div>
              </div>

              <div className="flex flex-col gap-1">
                <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Assigned Clinic</span>
                <span className="text-sm font-medium text-ink">
                  {viewingUser.clinic_id ? (clinicNames.get(viewingUser.clinic_id) ?? "— none —") : "— none —"}
                </span>
              </div>

              <div className="flex flex-col gap-1">
                <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Created Date</span>
                <span className="text-sm font-medium text-ink">
                  {viewingUser.created_at ? formatPhilippineTime(viewingUser.created_at) : "—"}
                </span>
              </div>
            </div>

            <div className="flex flex-col gap-1 rounded-md bg-surface-alt p-3">
              <span className="text-[11px] font-semibold text-ink-muted">Account ID</span>
              <span className="font-mono text-xs text-ink">{viewingUser.id}</span>
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
          <form className="flex flex-col gap-4" onSubmit={saveEdit}>
            <div className="flex flex-col gap-1">
              <Label>Account</Label>
              <div className="text-sm font-semibold text-ink">{editingUser.name} ({editingUser.email})</div>
            </div>

            <div className="flex flex-col gap-1">
              <Label htmlFor="edit-user-role">Role</Label>
              <Select
                id="edit-user-role"
                className="h-10 w-full"
                value={editRole}
                onChange={(e) => setEditRole(e.target.value as UserRole)}
              >
                {ROLES.map((r) => (
                  <option key={r} value={r}>
                    {r}
                  </option>
                ))}
              </Select>
            </div>

            <div className="flex flex-col gap-1">
              <Label htmlFor="edit-user-clinic">Clinic</Label>
              <Select
                id="edit-user-clinic"
                className="h-10 w-full"
                value={editClinicId}
                onChange={(e) => setEditClinicId(e.target.value)}
              >
                <option value="">— none —</option>
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

      <ConfirmDeleteDialog
        open={pendingDelete !== null}
        title="Delete user"
        description={
          pendingDelete
            ? `Delete ${pendingDelete.name} (${pendingDelete.email})? This can't be undone. Accounts that still own dog profiles or authored records can't be deleted.`
            : ""
        }
        busy={deleting}
        onConfirm={confirmDelete}
        onClose={() => setPendingDelete(null)}
      />
    </Card>
  );
}

/** No-API-key Google Maps embed built from a clinic's free-text address —
 * same formula the mobile app uses (see Clinic.mapEmbedUrl in models.dart)
 * so admin preview and the owner app's "Partner Clinics" map always match. */
function clinicMapEmbedUrl(address: string) {
  return `https://maps.google.com/maps?q=${encodeURIComponent(address.trim())}&output=embed`;
}

/** Edit-clinic form, shared by the dialog below — same fields as "Add clinic". */
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

function ClinicsTab({
  clinics,
  onCreated,
  onChanged,
  onDeleted,
  onError,
}: {
  clinics: Clinic[];
  onCreated: (c: Clinic) => void;
  onChanged: (c: Clinic) => void;
  onDeleted: (id: string, name: string) => void;
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
        <Button type="button" onClick={() => setAddOpen(true)}>
          <Plus size={14} /> Add clinic
        </Button>
      </CardHeader>
      <CardContent className="flex flex-col gap-5">
        <Table>
          <THead>
            <Tr className="border-t-0">
              <Th>Name</Th>
              <Th>Address</Th>
              <Th>Contact</Th>
              <Th>Actions</Th>
            </Tr>
          </THead>
          <TBody>
            {clinics.map((c) => (
              <Tr key={c.id}>
                <Td className="font-semibold">{c.name}</Td>
                <Td className="text-ink-muted">{c.address ?? "—"}</Td>
                <Td className="text-ink-muted">{c.contact_number ?? "—"}</Td>
                <Td>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      aria-label={`View details for ${c.name}`}
                      title="View Clinic Details & Map"
                      onClick={() => setViewingClinic(c)}
                      className="flex h-8 w-8 items-center justify-center rounded-md bg-surface-alt text-ink-muted transition-colors duration-fast hover:bg-brand-soft hover:text-brand-strong"
                    >
                      <Eye size={15} />
                    </button>
                    <button
                      type="button"
                      aria-label={`Edit ${c.name}`}
                      title="Edit Clinic Details"
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
            ))}
          </TBody>
        </Table>
      </CardContent>

      {/* Add Clinic Dialog */}
      <Dialog open={addOpen} onClose={() => setAddOpen(false)} title="Add clinic">
        <form className="flex flex-col gap-3" onSubmit={submit}>
          <ClinicFields
            idPrefix="clinic"
            name={name}
            address={address}
            contact={contact}
            onName={setName}
            onAddress={setAddress}
            onContact={setContact}
          />
          <div className="flex justify-end gap-2">
            <Button type="button" variant="secondary" onClick={() => setAddOpen(false)} disabled={saving}>
              Cancel
            </Button>
            <Button type="submit" disabled={saving || name.trim() === ""}>
              {saving ? "Adding…" : "Add clinic"}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* View Clinic Dialog */}
      <Dialog open={viewingClinic !== null} onClose={() => setViewingClinic(null)} title="Clinic details">
        {viewingClinic && (
          <div className="flex flex-col gap-4 py-1">
            <div className="flex flex-col gap-1 border-b border-hairline pb-3">
              <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Clinic Name</span>
              <span className="text-base font-bold text-ink">{viewingClinic.name}</span>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="flex flex-col gap-1">
                <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Address</span>
                <span className="text-sm font-medium text-ink">{viewingClinic.address ?? "—"}</span>
              </div>

              <div className="flex flex-col gap-1">
                <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Contact</span>
                <span className="text-sm font-medium text-ink">{viewingClinic.contact_number ?? "—"}</span>
              </div>
            </div>

            {viewingClinic.address && viewingClinic.address.trim() !== "" && (
              <div className="overflow-hidden rounded-lg border border-hairline">
                <iframe
                  title="Clinic location preview"
                  className="h-44 w-full"
                  loading="lazy"
                  src={clinicMapEmbedUrl(viewingClinic.address)}
                />
              </div>
            )}

            <div className="flex flex-col gap-1 rounded-md bg-surface-alt p-3">
              <span className="text-[11px] font-semibold text-ink-muted">Clinic ID</span>
              <span className="font-mono text-xs text-ink">{viewingClinic.id}</span>
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
        <form className="flex flex-col gap-3" onSubmit={saveEdit}>
          <ClinicFields
            idPrefix="clinic-edit"
            name={editName}
            address={editAddress}
            contact={editContact}
            onName={setEditName}
            onAddress={setEditAddress}
            onContact={setEditContact}
          />
          <div className="flex justify-end gap-2">
            <Button type="button" variant="secondary" onClick={() => setEditing(null)} disabled={editSaving}>
              Cancel
            </Button>
            <Button type="submit" disabled={editSaving || editName.trim() === ""}>
              {editSaving ? "Saving…" : "Save"}
            </Button>
          </div>
        </form>
      </Dialog>

      <ConfirmDeleteDialog
        open={pendingDelete !== null}
        title="Delete clinic"
        description={
          pendingDelete
            ? `Delete ${pendingDelete.name}? This can't be undone. Clinics still linked to staff or dogs can't be deleted — reassign them first.`
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
  maintenance: "bg-amber-100 text-amber-800 border border-amber-200 font-semibold",
  inactive: "bg-slate-100 text-slate-800 border border-slate-200 font-semibold",
};

function DevicesTab({
  devices,
  dogs,
  clinics,
  dogNames,
  clinicNames,
  onChanged,
  onRegistered,
  onDeleted,
  onDogClinicChanged,
  onToast,
}: {
  devices: Device[];
  dogs: Dog[];
  clinics: Clinic[];
  dogNames: Map<string, string>;
  clinicNames: Map<string, string>;
  onChanged: (d: Device) => void;
  onRegistered: (d: Device) => void;
  onDeleted: (id: string) => void;
  onDogClinicChanged: (d: Dog) => void;
  onToast: (kind: "success" | "error", message: string) => void;
}) {
  const [code, setCode] = useState("");
  const [firmware, setFirmware] = useState("");
  const [saving, setSaving] = useState(false);
  const [addOpen, setAddOpen] = useState(false);

  const [viewingDevice, setViewingDevice] = useState<Device | null>(null);

  const [editingDevice, setEditingDevice] = useState<Device | null>(null);
  const [editStatus, setEditStatus] = useState<DeviceStatus>("active");
  const [editDogId, setEditDogId] = useState("");
  const [editSaving, setEditSaving] = useState(false);

  const [pendingDelete, setPendingDelete] = useState<Device | null>(null);
  const [deleting, setDeleting] = useState(false);

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
      setFirmware("");
      onRegistered(device);
      onToast("success", `${device.device_code} registered`);
      setAddOpen(false);
    } catch (err) {
      onToast("error", friendlyError(err, "register the device"));
    } finally {
      setSaving(false);
    }
  }

  async function patch(device: Device, patchBody: { dog_id?: string | null; status?: DeviceStatus }) {
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

  async function assignDogClinic(dog: Dog, clinicId: string | null) {
    try {
      onDogClinicChanged(await updateDogClinic(supabase, dog.id, clinicId));
      onToast("success", `${dog.name}'s clinic updated`);
    } catch (err) {
      onToast("error", friendlyError(err, "update the dog's clinic"));
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
              Register harnesses, assign them to dogs, or take them out of service.
            </CardDescription>
          </div>
          <Button type="button" onClick={() => setAddOpen(true)}>
            <Plus size={14} /> Register device
          </Button>
        </CardHeader>
        <CardContent className="flex flex-col gap-5">
          <Table>
            <THead>
              <Tr className="border-t-0">
                <Th>Code</Th>
                <Th>Status</Th>
                <Th>Assigned dog</Th>
                <Th>Last seen (PST)</Th>
                <Th>Actions</Th>
              </Tr>
            </THead>
            <TBody>
              {devices.map((d) => (
                <Tr key={d.id}>
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
              ))}
            </TBody>
          </Table>
        </CardContent>

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
                      {dog.name}
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
              ? `Delete ${pendingDelete.device_code}? This can't be undone. Devices with telemetry history can't be deleted — set status to inactive instead.`
              : ""
          }
          busy={deleting}
          onConfirm={confirmDelete}
          onClose={() => setPendingDelete(null)}
        />
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Dog ↔ clinic assignment</CardTitle>
          <CardDescription>
            A dog appears on a clinic&apos;s live board once its clinic is set (docs/09
            linkage). Owners can also pick a clinic in the app.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <THead>
              <Tr className="border-t-0">
                <Th>Dog</Th>
                <Th>Owner-visible name</Th>
                <Th>Clinic</Th>
              </Tr>
            </THead>
            <TBody>
              {dogs.map((dog) => (
                <Tr key={dog.id}>
                  <Td className="font-semibold">{dogNames.get(dog.id) ?? dog.name}</Td>
                  <Td className="text-ink-muted">{dog.breed ?? "—"}</Td>
                  <Td>
                    <Select
                      aria-label={`Clinic for ${dog.name}`}
                      className="h-9 w-56"
                      value={dog.clinic_id ?? ""}
                      onChange={(e) => assignDogClinic(dog, e.target.value === "" ? null : e.target.value)}
                    >
                      <option value="">— home only —</option>
                      {clinics.map((c) => (
                        <option key={c.id} value={c.id}>
                          {clinicNames.get(c.id) ?? c.name}
                        </option>
                      ))}
                    </Select>
                  </Td>
                </Tr>
              ))}
            </TBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
