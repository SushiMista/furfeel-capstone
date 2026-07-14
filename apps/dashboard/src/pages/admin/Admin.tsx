import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";
import { Plus } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  createClinic,
  fetchAllDevices,
  fetchAllDogs,
  fetchAllUsers,
  fetchClinics,
  registerDevice,
  updateDevice,
  updateDogClinic,
  updateUserRoleClinic,
} from "../../lib/adminQueries.ts";
import { useCurrentRole } from "../../lib/useCurrentRole.ts";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
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
type Tab = "users" | "clinics" | "devices";

/** Admin (docs/05 §4): manage users (role + clinic), clinics, and devices.
 * The page is offered to the admin role only as UX; the users_update_admin /
 * clinics_admin_manage / devices_admin_all RLS policies are the actual gate. */
export function Admin() {
  const { role, loading: roleLoading } = useCurrentRole();
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
        {(["users", "clinics", "devices"] as Tab[]).map((t) => (
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
          onChanged={(u) => {
            setUsers((prev) => prev.map((x) => (x.id === u.id ? u : x)));
            toast("success", `${u.name} updated`);
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
          onDogClinicChanged={(dog) =>
            setDogs((prev) => prev.map((x) => (x.id === dog.id ? dog : x)))
          }
          onToast={toast}
        />
      )}
    </div>
  );
}

function UsersTab({
  users,
  clinics,
  onChanged,
  onError,
}: {
  users: User[];
  clinics: Clinic[];
  onChanged: (u: User) => void;
  onError: (message: string) => void;
}) {
  async function apply(user: User, role: UserRole, clinicId: string | null) {
    try {
      onChanged(await updateUserRoleClinic(supabase, user.id, role, clinicId));
    } catch (err) {
      onError(err instanceof Error ? err.message : "Failed to update the user");
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Users</CardTitle>
        <CardDescription>
          Assign roles and clinics. New accounts sign up in the apps and start as owners.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Table>
          <THead>
            <Tr className="border-t-0">
              <Th>Name</Th>
              <Th>Email</Th>
              <Th>Role</Th>
              <Th>Clinic</Th>
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
              </Tr>
            ))}
          </TBody>
        </Table>
      </CardContent>
    </Card>
  );
}

function ClinicsTab({
  clinics,
  onCreated,
  onError,
}: {
  clinics: Clinic[];
  onCreated: (c: Clinic) => void;
  onError: (message: string) => void;
}) {
  const [name, setName] = useState("");
  const [address, setAddress] = useState("");
  const [contact, setContact] = useState("");
  const [saving, setSaving] = useState(false);

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

  return (
    <Card>
      <CardHeader>
        <CardTitle>Clinics</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-5">
        <form className="flex flex-wrap items-end gap-3" onSubmit={submit}>
          <div className="flex flex-col gap-1">
            <Label htmlFor="clinic-name">Name</Label>
            <Input id="clinic-name" value={name} onChange={(e) => setName(e.target.value)} required />
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="clinic-address">Address</Label>
            <Input id="clinic-address" value={address} onChange={(e) => setAddress(e.target.value)} />
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="clinic-contact">Contact</Label>
            <Input id="clinic-contact" value={contact} onChange={(e) => setContact(e.target.value)} />
          </div>
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
            </Tr>
          </THead>
          <TBody>
            {clinics.map((c) => (
              <Tr key={c.id}>
                <Td className="font-semibold">{c.name}</Td>
                <Td className="text-ink-muted">{c.address ?? "—"}</Td>
                <Td className="text-ink-muted">{c.contact_number ?? "—"}</Td>
              </Tr>
            ))}
          </TBody>
        </Table>
      </CardContent>
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
  onDogClinicChanged: (d: Dog) => void;
  onToast: (kind: "success" | "error", message: string) => void;
}) {
  const [code, setCode] = useState("");
  const [firmware, setFirmware] = useState("");
  const [saving, setSaving] = useState(false);

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
                </Tr>
              ))}
            </TBody>
          </Table>
        </CardContent>
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
