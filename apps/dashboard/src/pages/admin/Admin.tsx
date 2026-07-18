import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";
import {
  Activity,
  Bell,
  Building2,
  Dog as DogIcon,
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
import { useToast } from "../../components/ui/toast.tsx";
import { cn } from "../../lib/cn.ts";
import type {
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
  const { role, loading: roleLoading } = useCurrentRole();
  const { session } = useAuth();
  const toast = useToast();
  const [tab, setTab] = useState<Tab>("users");
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
      setError(err instanceof Error ? err.message : "Failed to load admin data");
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

  return (
    <div className="flex flex-col gap-5">
      <h1 className="m-0 text-2xl font-bold text-ink">Admin</h1>

      <div className="flex gap-2">
        {(["users", "clinics", "devices", "health"] as Tab[]).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => setTab(t)}
            className={cn(
              "rounded-md px-4 py-2 text-sm font-semibold capitalize transition-colors duration-fast",
              tab === t
                ? "bg-brand-soft text-brand-strong"
                : "text-ink-muted hover:bg-surface-alt hover:text-ink",
            )}
          >
            {t}
          </button>
        ))}
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
  const [health, setHealth] = useState<SystemHealth | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchSystemHealth(supabase)
      .then(setHealth)
      .catch((err) => setError(err instanceof Error ? err.message : "Failed to load system health"));
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
        {health.last_telemetry_at ? new Date(health.last_telemetry_at).toLocaleString() : "never"}
        {" · "}Device fleet: {devices.length} registered (
        {devices.length - online - offline} inactive/maintenance)
      </p>
    </div>
  );
}

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
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [newRole, setNewRole] = useState<UserRole>("owner");
  const [newClinicId, setNewClinicId] = useState("");
  const [saving, setSaving] = useState(false);
  const [pendingDelete, setPendingDelete] = useState<User | null>(null);
  const [deleting, setDeleting] = useState(false);

  async function apply(user: User, role: UserRole, clinicId: string | null) {
    try {
      onChanged(await updateUserRoleClinic(supabase, user.id, role, clinicId));
    } catch (err) {
      onError(err instanceof Error ? err.message : "Failed to update the user");
    }
  }

  async function confirmDelete() {
    if (!pendingDelete) return;
    setDeleting(true);
    try {
      await deleteUserAccount(supabase, pendingDelete.id);
      onDeleted(pendingDelete.id, pendingDelete.name);
      setPendingDelete(null);
    } catch (err) {
      onError(err instanceof Error ? err.message : "Failed to delete the user");
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
    } catch (err) {
      onError(err instanceof Error ? err.message : "Failed to create the user");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Users</CardTitle>
        <CardDescription>
          Add accounts and assign roles and clinics. Accounts created here can sign in
          right away — no email confirmation needed. Users can also sign up in the apps
          themselves and start as owners.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-5">
        <form className="flex flex-wrap items-end gap-3" onSubmit={submit}>
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
              className="h-10 w-36"
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
              className="h-10 w-48"
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
          <Button type="submit" disabled={saving || name.trim() === "" || email.trim() === "" || password.length < 6}>
            <Plus size={14} /> Add user
          </Button>
        </form>

        <Table>
          <THead>
            <Tr className="border-t-0">
              <Th>Name</Th>
              <Th>Email</Th>
              <Th>Role</Th>
              <Th>Clinic</Th>
              <Th></Th>
            </Tr>
          </THead>
          <TBody>
            {users.map((u) => (
              <Tr key={u.id}>
                <Td className="font-semibold">{u.name}</Td>
                <Td className="text-ink-muted">{u.email}</Td>
                <Td>
                  <Select
                    aria-label={`Role for ${u.name}`}
                    className="h-9 w-36"
                    value={u.role}
                    onChange={(e) => apply(u, e.target.value as UserRole, u.clinic_id)}
                  >
                    {ROLES.map((r) => (
                      <option key={r} value={r}>
                        {r}
                      </option>
                    ))}
                  </Select>
                </Td>
                <Td>
                  <Select
                    aria-label={`Clinic for ${u.name}`}
                    className="h-9 w-48"
                    value={u.clinic_id ?? ""}
                    onChange={(e) => apply(u, u.role, e.target.value === "" ? null : e.target.value)}
                  >
                    <option value="">— none —</option>
                    {clinics.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </Select>
                </Td>
                <Td>
                  {u.id !== currentUserId && (
                    <Button
                      variant="ghost"
                      size="sm"
                      aria-label={`Delete ${u.name}`}
                      onClick={() => setPendingDelete(u)}
                    >
                      <Trash2 size={14} />
                    </Button>
                  )}
                </Td>
              </Tr>
            ))}
          </TBody>
        </Table>
      </CardContent>

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
    } catch (err) {
      onError(err instanceof Error ? err.message : "Failed to create the clinic");
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
      onError(err instanceof Error ? err.message : "Failed to update the clinic");
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
      onError(err instanceof Error ? err.message : "Failed to delete the clinic");
    } finally {
      setDeleting(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Clinics</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-5">
        <form className="flex flex-wrap items-end gap-3" onSubmit={submit}>
          <ClinicFields
            idPrefix="clinic"
            name={name}
            address={address}
            contact={contact}
            onName={setName}
            onAddress={setAddress}
            onContact={setContact}
          />
          <Button type="submit" disabled={saving || name.trim() === ""}>
            <Plus size={14} /> Add clinic
          </Button>
        </form>

        <Table>
          <THead>
            <Tr className="border-t-0">
              <Th>Name</Th>
              <Th>Address</Th>
              <Th>Contact</Th>
              <Th></Th>
            </Tr>
          </THead>
          <TBody>
            {clinics.map((c) => (
              <Tr key={c.id}>
                <Td className="font-semibold">{c.name}</Td>
                <Td className="text-ink-muted">{c.address ?? "—"}</Td>
                <Td className="text-ink-muted">{c.contact_number ?? "—"}</Td>
                <Td>
                  <div className="flex gap-1">
                    <Button variant="ghost" size="sm" aria-label={`Edit ${c.name}`} onClick={() => startEdit(c)}>
                      <Pencil size={14} />
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      aria-label={`Delete ${c.name}`}
                      onClick={() => setPendingDelete(c)}
                    >
                      <Trash2 size={14} />
                    </Button>
                  </div>
                </Td>
              </Tr>
            ))}
          </TBody>
        </Table>
      </CardContent>

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
    } catch (err) {
      onToast("error", err instanceof Error ? err.message : "Failed to register the device");
    } finally {
      setSaving(false);
    }
  }

  async function patch(device: Device, patchBody: { dog_id?: string | null; status?: DeviceStatus }) {
    try {
      onChanged(await updateDevice(supabase, device.id, patchBody));
      onToast("success", `${device.device_code} updated`);
    } catch (err) {
      onToast("error", err instanceof Error ? err.message : "Failed to update the device");
    }
  }

  async function assignDogClinic(dog: Dog, clinicId: string | null) {
    try {
      onDogClinicChanged(await updateDogClinic(supabase, dog.id, clinicId));
      onToast("success", `${dog.name}'s clinic updated`);
    } catch (err) {
      onToast("error", err instanceof Error ? err.message : "Failed to update the dog's clinic");
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
      onToast("error", err instanceof Error ? err.message : "Failed to delete the device");
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <Card>
        <CardHeader>
          <CardTitle>Devices</CardTitle>
          <CardDescription>
            Register harnesses, assign them to dogs, or take them out of service.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-5">
          <form className="flex flex-wrap items-end gap-3" onSubmit={register}>
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
            <Button type="submit" disabled={saving || code.trim() === ""}>
              <Plus size={14} /> Register device
            </Button>
          </form>

          <Table>
            <THead>
              <Tr className="border-t-0">
                <Th>Code</Th>
                <Th>Status</Th>
                <Th>Assigned dog</Th>
                <Th>Last seen</Th>
                <Th></Th>
              </Tr>
            </THead>
            <TBody>
              {devices.map((d) => (
                <Tr key={d.id}>
                  <Td className="font-semibold">{d.device_code}</Td>
                  <Td>
                    <Select
                      aria-label={`Status for ${d.device_code}`}
                      className="h-9 w-36"
                      value={d.status}
                      onChange={(e) => patch(d, { status: e.target.value as DeviceStatus })}
                    >
                      {DEVICE_STATUSES.map((s) => (
                        <option key={s} value={s}>
                          {s}
                        </option>
                      ))}
                    </Select>
                  </Td>
                  <Td>
                    <Select
                      aria-label={`Dog for ${d.device_code}`}
                      className="h-9 w-44"
                      value={d.dog_id ?? ""}
                      onChange={(e) => patch(d, { dog_id: e.target.value === "" ? null : e.target.value })}
                    >
                      <option value="">— unassigned —</option>
                      {dogs.map((dog) => (
                        <option key={dog.id} value={dog.id}>
                          {dog.name}
                        </option>
                      ))}
                    </Select>
                  </Td>
                  <Td className="text-xs text-ink-muted">
                    {d.last_seen_at ? new Date(d.last_seen_at).toLocaleString() : "never"}
                  </Td>
                  <Td>
                    <Button
                      variant="ghost"
                      size="sm"
                      aria-label={`Delete ${d.device_code}`}
                      onClick={() => setPendingDelete(d)}
                    >
                      <Trash2 size={14} />
                    </Button>
                  </Td>
                </Tr>
              ))}
            </TBody>
          </Table>
        </CardContent>

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
