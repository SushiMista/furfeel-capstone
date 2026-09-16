import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useState, useMemo, type FormEvent } from "react";
import { useSearchParams } from "react-router-dom";
import {
  Radio,
  Plus,
  Edit,
  Trash2,
  AlertTriangle,
  Search,
  Cpu,
  Dog as DogIcon,
  CheckCircle2,
  Info,
  Clock,
  RotateCcw,
  Sparkles,
} from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { fetchDevicesReadOnly, fetchDogs, type DeviceWithDog, type Dog } from "../../lib/queries.ts";
import {
  registerDevice,
  updateDevice,
  deleteDevice,
} from "../../lib/adminQueries.ts";
import { recordAuditLog, fetchPendingDeviceDeletionRequests } from "../../lib/auditLogger.ts";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { Badge } from "../../components/ui/badge.tsx";
import { Dialog } from "../../components/ui/dialog.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Input, Label, Select } from "../../components/ui/input.tsx";
import { useToast } from "../../components/ui/toast.tsx";
import { formatPhilippineTime } from "../../lib/time.ts";
import type { DeviceStatus } from "../../../../../packages/shared/types/index.ts";

const STATUS_BADGE: Record<string, "default" | "neutral" | "outline"> = {
  active: "default",
  offline: "outline",
  inactive: "neutral",
  maintenance: "neutral",
};

export function Devices() {
  const [searchParams] = useSearchParams();
  const { profile } = useAuth();
  const { toast } = useToast();
  const role = profile?.role;
  const isAdmin = role === "admin";

  const [devices, setDevices] = useState<DeviceWithDog[]>([]);
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [deletionRequests, setDeletionRequests] = useState<
    Map<string, { reason: string; requestedAt: string; requestedBy: string }>
  >(new Map());
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Search & Filters
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [assignmentFilter, setAssignmentFilter] = useState("all");

  // Modals state
  const [registerOpen, setRegisterOpen] = useState(false);
  const [editingDevice, setEditingDevice] = useState<DeviceWithDog | null>(null);
  const [requestingDeleteDevice, setRequestingDeleteDevice] = useState<DeviceWithDog | null>(null);
  const [adminDeleteDevice, setAdminDeleteDevice] = useState<DeviceWithDog | null>(null);
  const [saving, setSaving] = useState(false);

  // Register Form State
  const [newDeviceCode, setNewDeviceCode] = useState("");
  const [newFirmware, setNewFirmware] = useState("0.1.0");

  // Edit Form State
  const [editStatus, setEditStatus] = useState<DeviceStatus>("active");
  const [editFirmware, setEditFirmware] = useState("");
  const [editDogId, setEditDogId] = useState<string>("");

  // Deletion Request Form State
  const [deletionReason, setDeletionReason] = useState("");

  const load = useCallback(async () => {
    try {
      setLoading(true);
      const [devList, dogList, delRequests] = await Promise.all([
        fetchDevicesReadOnly(supabase),
        fetchDogs(supabase).catch(() => [] as Dog[]),
        fetchPendingDeviceDeletionRequests().catch(() => new Map()),
      ]);
      setDevices(devList);
      setDogs(dogList);
      setDeletionRequests(delRequests);
      setError(null);
    } catch (err) {
      setError(friendlyError(err, "load devices"));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  // Filtered devices
  const filteredDevices = useMemo(() => {
    return devices.filter((d) => {
      const q = searchQuery.toLowerCase().trim();
      const hasDelRequest = deletionRequests.has(d.id);

      const matchesSearch =
        !q ||
        d.device_code.toLowerCase().includes(q) ||
        (d.dog?.name && d.dog.name.toLowerCase().includes(q)) ||
        (d.firmware_version && d.firmware_version.toLowerCase().includes(q));

      let matchesStatus = true;
      if (statusFilter === "deletion_requested") {
        matchesStatus = hasDelRequest;
      } else if (statusFilter !== "all") {
        matchesStatus = d.status === statusFilter;
      }

      let matchesAssignment = true;
      if (assignmentFilter === "assigned") {
        matchesAssignment = Boolean(d.dog_id);
      } else if (assignmentFilter === "unassigned") {
        matchesAssignment = !d.dog_id;
      }

      return matchesSearch && matchesStatus && matchesAssignment;
    });
  }, [devices, searchQuery, statusFilter, assignmentFilter, deletionRequests]);

  // Open Edit Dialog
  function handleOpenEdit(dev: DeviceWithDog) {
    setEditingDevice(dev);
    setEditStatus(dev.status);
    setEditFirmware(dev.firmware_version || "0.1.0");
    setEditDogId(dev.dog_id || "");
  }

  // Save Edit Device
  async function handleSaveEdit(e: FormEvent) {
    e.preventDefault();
    if (!editingDevice) return;

    setSaving(true);
    try {
      await updateDevice(supabase, editingDevice.id, {
        status: editStatus,
        firmware_version: editFirmware.trim() || null,
        dog_id: editDogId || null,
      });

      const assignedDog = dogs.find((d) => d.id === editDogId);
      setDevices((prev) =>
        prev.map((d) =>
          d.id === editingDevice.id
            ? {
                ...d,
                status: editStatus,
                firmware_version: editFirmware.trim() || null,
                dog_id: editDogId || null,
                dog: assignedDog ? { id: assignedDog.id, name: assignedDog.name } : null,
              }
            : d,
        ),
      );

      toast("success", `Updated device ${editingDevice.device_code}`);
      setEditingDevice(null);
      load().catch(() => {});
    } catch (err) {
      toast("error", friendlyError(err, "update device"));
    } finally {
      setSaving(false);
    }
  }

  // Handle Register New Device
  async function handleRegisterDevice(e: FormEvent) {
    e.preventDefault();
    if (!newDeviceCode.trim()) {
      toast("error", "Please provide a device code.");
      return;
    }

    setSaving(true);
    try {
      const newDev = await registerDevice(
        supabase,
        newDeviceCode.trim().toUpperCase(),
        newFirmware.trim() || "0.1.0",
      );
      setDevices((prev) => [
        {
          ...newDev,
          dog: null,
          last_seen_at: null,
          battery_percent: null,
        } as DeviceWithDog,
        ...prev,
      ]);
      toast("success", `Registered new collar: ${newDev.device_code}`);
      setRegisterOpen(false);
      setNewDeviceCode("");
      setNewFirmware("0.1.0");
      load().catch(() => {});
    } catch (err) {
      toast("error", friendlyError(err, "register device"));
    } finally {
      setSaving(false);
    }
  }

  // Handle Request Deletion (by Vet)
  async function handleRequestDeletion(e: FormEvent) {
    e.preventDefault();
    if (!requestingDeleteDevice) return;
    const target = requestingDeleteDevice;
    const reasonText = deletionReason.trim();

    if (!reasonText) {
      toast("error", "Please explain why this device needs to be deleted or decommissioned.");
      return;
    }

    setSaving(true);
    try {
      // 1. Optimistic UI update immediately (no refresh needed)
      setDevices((prev) =>
        prev.map((d) =>
          d.id === target.id
            ? {
                ...d,
                status: "maintenance" as DeviceStatus,
                dog_id: null,
                dog: null,
              }
            : d,
        ),
      );
      setDeletionRequests((prev) => {
        const next = new Map(prev);
        next.set(target.id, {
          reason: reasonText,
          requestedAt: new Date().toISOString(),
          requestedBy: profile?.name || profile?.email || "Clinic Staff",
        });
        return next;
      });

      // Close modal immediately
      setRequestingDeleteDevice(null);
      setDeletionReason("");

      // 2. Set device status to maintenance in backend
      await updateDevice(supabase, target.id, {
        status: "maintenance",
        dog_id: null, // unassign from dog
      });

      // 3. Record audit log request for Admin
      await recordAuditLog({
        actor_role: (role as any) || "veterinarian",
        surface: "dashboard",
        action: "device.deletion_requested",
        target_resource: "devices",
        target_id: target.id,
        clinic_id: profile?.clinic_id ?? null,
        details: {
          device_code: target.device_code,
          dog_name: target.dog?.name ?? null,
          reason: reasonText,
          requested_at: new Date().toISOString(),
          requested_by: profile?.name || profile?.email || "Clinic Staff",
        },
        severity: "warning",
      });

      toast("success", `Deletion request for ${target.device_code} submitted to Admin.`);
      load().catch(() => {});
    } catch (err) {
      toast("error", friendlyError(err, "submit deletion request"));
    } finally {
      setSaving(false);
    }
  }

  // Handle Admin Immediate Purge / Approval
  async function handleAdminApproveDelete() {
    if (!adminDeleteDevice) return;
    const targetId = adminDeleteDevice.id;
    const targetCode = adminDeleteDevice.device_code;

    setSaving(true);
    try {
      // Optimistic delete
      setDevices((prev) => prev.filter((d) => d.id !== targetId));
      setDeletionRequests((prev) => {
        const next = new Map(prev);
        next.delete(targetId);
        return next;
      });
      setAdminDeleteDevice(null);

      await deleteDevice(supabase, targetId);
      toast("success", `Device ${targetCode} permanently purged.`);
      load().catch(() => {});
    } catch (err) {
      toast("error", friendlyError(err, "delete device"));
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <CardSkeleton lines={6} />;
  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );

  const pendingCount = deletionRequests.size;

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="m-0 text-2xl font-black text-ink tracking-tight flex items-center gap-2.5">
            <Radio className="text-brand h-7 w-7" />
            <span>Device Hardware Fleet</span>
          </h1>
          <p className="text-sm text-ink-muted mt-1">
            Build, assign, and manage telemetry sensor collars linked to your clinical operations.
          </p>
        </div>

        <div className="flex items-center gap-2.5">
          <Button
            type="button"
            onClick={() => setRegisterOpen(true)}
            className="flex items-center gap-2 font-bold shadow-xs bg-brand hover:bg-brand-strong text-white"
          >
            <Plus size={16} />
            <span>+ Build / Register Collar</span>
          </Button>
        </div>
      </div>

      {/* Notice for Pending Deletion Requests if any */}
      {pendingCount > 0 && (
        <div className="flex items-center justify-between p-3.5 rounded-xl border border-warning/40 bg-warning/10 text-xs">
          <div className="flex items-center gap-2.5">
            <AlertTriangle size={16} className="text-warning shrink-0" />
            <span className="font-bold text-ink">
              {pendingCount} device{pendingCount > 1 ? "s have" : " has"} a pending Deletion / Decommission request
              submitted for Administrator review.
            </span>
          </div>
          <button
            type="button"
            onClick={() => setStatusFilter("deletion_requested")}
            className="font-bold text-brand hover:underline"
          >
            View Requests →
          </button>
        </div>
      )}

      {/* Main Table Card */}
      <Card className="border-hairline shadow-xs">
        <CardHeader className="pb-4">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
            <div>
              <CardTitle className="text-lg font-bold text-ink">
                Hardware Inventory ({filteredDevices.length})
              </CardTitle>
              <CardDescription>
                Live collar telemetry state, firmware revisions, and patient dog bindings.
              </CardDescription>
            </div>

            {/* Filter & Search Bar */}
            <div className="flex flex-col sm:flex-row items-center gap-2.5 w-full md:w-auto">
              <div className="relative w-full sm:w-56">
                <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-ink-muted" />
                <Input
                  placeholder="Search code, dog, FW..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-9 text-xs h-9"
                />
              </div>

              <Select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="text-xs h-9 w-full sm:w-36"
              >
                <option value="all">All Statuses</option>
                <option value="active">Active</option>
                <option value="offline">Offline</option>
                <option value="inactive">Inactive</option>
                <option value="maintenance">Maintenance</option>
                {pendingCount > 0 && <option value="deletion_requested">⚠️ Pending Deletion ({pendingCount})</option>}
              </Select>

              <Select
                value={assignmentFilter}
                onChange={(e) => setAssignmentFilter(e.target.value)}
                className="text-xs h-9 w-full sm:w-36"
              >
                <option value="all">All Collars</option>
                <option value="assigned">Assigned to Dog</option>
                <option value="unassigned">Unassigned</option>
              </Select>
            </div>
          </div>
        </CardHeader>

        <CardContent className="p-0">
          {filteredDevices.length === 0 ? (
            <div className="p-8">
              <EmptyState>No devices matched the selected criteria.</EmptyState>
            </div>
          ) : (
            <Table>
              <THead>
                <Tr className="border-t-0 bg-surface-alt/40">
                  <Th className="pl-4">Device Code</Th>
                  <Th>Status</Th>
                  <Th>Assigned Patient</Th>
                  <Th>Battery</Th>
                  <Th>Firmware</Th>
                  <Th>Last Seen</Th>
                  <Th className="text-right pr-4">Actions</Th>
                </Tr>
              </THead>
              <TBody>
                {filteredDevices.map((d) => {
                  const delRequest = deletionRequests.get(d.id);

                  return (
                    <Tr key={d.id} className="hover:bg-surface-alt/30 transition-colors">
                      {/* Code */}
                      <Td className="pl-4 font-mono font-black text-xs text-ink">
                        <div className="flex items-center gap-2">
                          <Cpu size={14} className="text-brand opacity-80" />
                          <span>{d.device_code}</span>
                        </div>
                      </Td>

                      {/* Status */}
                      <Td>
                        <div className="flex flex-col gap-1 items-start">
                          <Badge variant={STATUS_BADGE[d.status] ?? "neutral"} className="capitalize text-[11px]">
                            {d.status}
                          </Badge>
                          {(delRequest || d.status === "maintenance") && (
                            <span
                              className="inline-flex items-center gap-1 text-[10px] font-bold text-amber-600 dark:text-amber-400 bg-amber-500/10 px-1.5 py-0.5 rounded"
                              title={delRequest ? `Requested by ${delRequest.requestedBy}: ${delRequest.reason}` : "Awaiting Admin Review"}
                            >
                              <AlertTriangle size={10} /> Pending Admin Deletion
                            </span>
                          )}
                        </div>
                      </Td>

                      {/* Assigned Dog */}
                      <Td>
                        {d.dog ? (
                          <div className="flex items-center gap-1.5 text-xs font-bold text-ink">
                            <DogIcon size={13} className="text-brand" />
                            <span>{d.dog.name}</span>
                          </div>
                        ) : (
                          <span className="text-xs text-ink-muted italic">— unassigned —</span>
                        )}
                      </Td>

                      {/* Battery */}
                      <Td className="tabular-nums text-xs font-medium text-ink">
                        {d.battery_percent != null ? `${d.battery_percent}%` : "—"}
                      </Td>

                      {/* Firmware */}
                      <Td className="text-xs text-ink-muted font-mono">{d.firmware_version ?? "0.1.0"}</Td>

                      {/* Last Seen */}
                      <Td className="text-[11px] text-ink-muted">
                        {d.last_seen_at ? formatPhilippineTime(d.last_seen_at) : "never"}
                      </Td>

                      {/* Actions */}
                      <Td className="text-right pr-4">
                        <div className="flex items-center justify-end gap-1.5">
                          {/* Edit / Reassign button */}
                          <Button
                            type="button"
                            variant="secondary"
                            size="sm"
                            onClick={() => handleOpenEdit(d)}
                            className="h-8 text-xs font-bold flex items-center gap-1"
                          >
                            <Edit size={13} />
                            <span>Edit / Assign</span>
                          </Button>

                          {/* Vet: Request Deletion / Admin: Direct Delete */}
                          {isAdmin ? (
                            <Button
                              type="button"
                              variant="secondary"
                              size="sm"
                              onClick={() => setAdminDeleteDevice(d)}
                              className="h-8 w-8 p-0 text-high-fg hover:bg-high-soft"
                              title="Admin: Purge Device"
                            >
                              <Trash2 size={13} />
                            </Button>
                          ) : (
                            <Button
                              type="button"
                              variant="secondary"
                              size="sm"
                              disabled={Boolean(delRequest || d.status === "maintenance")}
                              onClick={() => {
                                setRequestingDeleteDevice(d);
                                setDeletionReason("");
                              }}
                              className={`h-8 px-2 text-[11px] font-semibold flex items-center gap-1 ${
                                delRequest || d.status === "maintenance"
                                  ? "opacity-60 cursor-not-allowed bg-amber-500/10 text-amber-700 border-amber-300"
                                  : "text-high-fg hover:bg-high-soft"
                              }`}
                              title={delRequest || d.status === "maintenance" ? "Deletion request already queued for Administrator" : "Request Deletion from Admin"}
                            >
                              <Trash2 size={12} />
                              <span>{delRequest || d.status === "maintenance" ? "Pending Admin" : "Request Delete"}</span>
                            </Button>
                          )}
                        </div>
                      </Td>
                    </Tr>
                  );
                })}
              </TBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* ========================================================================= */}
      {/* MODAL 1: REGISTER / BUILD NEW COLLAR                                      */}
      {/* ========================================================================= */}
      {registerOpen && (
        <Dialog
          title="Build & Register Telemetry Collar"
          open={registerOpen}
          onClose={() => setRegisterOpen(false)}
        >
          <form onSubmit={handleRegisterDevice} className="flex flex-col gap-4">
            <p className="text-xs text-ink-muted m-0">
              Register a new hardware telemetry collar device code for live physiological monitoring.
            </p>

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="reg-code" className="text-xs font-bold text-ink">
                Collar Device Code <span className="text-high-fg">*</span>
              </Label>
              <Input
                id="reg-code"
                placeholder="e.g. FF-DEV-009"
                value={newDeviceCode}
                onChange={(e) => setNewDeviceCode(e.target.value.toUpperCase())}
                required
                className="font-mono uppercase font-bold"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="reg-fw" className="text-xs font-bold text-ink">
                Firmware Version
              </Label>
              <Input
                id="reg-fw"
                placeholder="0.1.0"
                value={newFirmware}
                onChange={(e) => setNewFirmware(e.target.value)}
              />
            </div>

            <div className="flex justify-end gap-2 pt-3 border-t border-hairline">
              <Button type="button" variant="secondary" onClick={() => setRegisterOpen(false)} disabled={saving}>
                Cancel
              </Button>
              <Button type="submit" disabled={saving || !newDeviceCode.trim()} className="font-bold bg-brand text-white">
                {saving ? "Registering..." : "Register Collar"}
              </Button>
            </div>
          </form>
        </Dialog>
      )}

      {/* ========================================================================= */}
      {/* MODAL 2: EDIT DEVICE / ASSIGN TO DOG                                      */}
      {/* ========================================================================= */}
      {editingDevice && (
        <Dialog
          title={`Edit Device: ${editingDevice.device_code}`}
          open={Boolean(editingDevice)}
          onClose={() => setEditingDevice(null)}
        >
          <form onSubmit={handleSaveEdit} className="flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="edit-status" className="text-xs font-bold text-ink">
                Hardware Status
              </Label>
              <Select
                id="edit-status"
                value={editStatus}
                onChange={(e) => setEditStatus(e.target.value as DeviceStatus)}
              >
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
                <option value="offline">Offline</option>
                <option value="maintenance">Maintenance</option>
              </Select>
            </div>

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="edit-dev-dog" className="text-xs font-bold text-ink">
                Assign to Patient Dog
              </Label>
              <Select
                id="edit-dev-dog"
                value={editDogId}
                onChange={(e) => setEditDogId(e.target.value)}
                className="h-10 text-xs font-medium"
              >
                <option value="">— Unassigned (Available in Fleet) —</option>
                {dogs.map((dog) => (
                  <option key={dog.id} value={dog.id}>
                    {dog.name} ({dog.breed || "Breed unspecified"})
                  </option>
                ))}
              </Select>
            </div>

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="edit-dev-fw" className="text-xs font-bold text-ink">
                Firmware Version
              </Label>
              <Input
                id="edit-dev-fw"
                value={editFirmware}
                onChange={(e) => setEditFirmware(e.target.value)}
              />
            </div>

            <div className="flex justify-end gap-2 pt-3 border-t border-hairline">
              <Button type="button" variant="secondary" onClick={() => setEditingDevice(null)} disabled={saving}>
                Cancel
              </Button>
              <Button type="submit" disabled={saving} className="font-bold bg-brand text-white">
                {saving ? "Saving..." : "Save Device Changes"}
              </Button>
            </div>
          </form>
        </Dialog>
      )}

      {/* ========================================================================= */}
      {/* MODAL 3: VET REQUEST DELETION MODAL                                       */}
      {/* ========================================================================= */}
      {requestingDeleteDevice && (
        <Dialog
          title="Request Device Deletion"
          open={Boolean(requestingDeleteDevice)}
          onClose={() => setRequestingDeleteDevice(null)}
        >
          <form onSubmit={handleRequestDeletion} className="flex flex-col gap-4">
            <div className="flex items-start gap-3 p-3 rounded-xl border border-warning/40 bg-warning/10 text-xs text-ink">
              <AlertTriangle size={18} className="text-warning shrink-0 mt-0.5" />
              <div>
                <span className="font-bold">Clinic Hardware Governance:</span>
                <p className="mt-1 m-0 text-ink-muted">
                  Veterinarians cannot directly purge hardware devices from the central database. Submitting this request
                  will set collar <strong>{requestingDeleteDevice.device_code}</strong> to <em>Maintenance</em> status
                  and notify the Administrator to review and execute the final deletion.
                </p>
              </div>
            </div>

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="del-reason" className="text-xs font-bold text-ink">
                Reason for Deletion / Decommission <span className="text-high-fg">*</span>
              </Label>
              <textarea
                id="del-reason"
                value={deletionReason}
                onChange={(e) => setDeletionReason(e.target.value)}
                required
                rows={3}
                className="rounded-xl border border-hairline bg-surface p-2.5 text-xs text-ink focus:outline-none focus:ring-2 focus:ring-brand/30"
                placeholder="e.g. Sensor electrode damaged beyond repair, battery swelling, obsolete prototype..."
              />
            </div>

            <div className="flex justify-end gap-2 pt-3 border-t border-hairline">
              <Button
                type="button"
                variant="secondary"
                onClick={() => setRequestingDeleteDevice(null)}
                disabled={saving}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                disabled={saving || !deletionReason.trim()}
                className="font-bold bg-amber-600 hover:bg-amber-700 text-white"
              >
                {saving ? "Submitting Request..." : "Submit Deletion Request"}
              </Button>
            </div>
          </form>
        </Dialog>
      )}

      {/* ========================================================================= */}
      {/* MODAL 4: ADMIN DIRECT PURGE MODAL                                         */}
      {/* ========================================================================= */}
      {adminDeleteDevice && (
        <Dialog
          title={`Admin: Purge Device ${adminDeleteDevice.device_code}`}
          open={Boolean(adminDeleteDevice)}
          onClose={() => setAdminDeleteDevice(null)}
        >
          <div className="flex flex-col gap-4">
            <p className="text-xs text-ink m-0">
              Are you sure you want to permanently purge device <strong>{adminDeleteDevice.device_code}</strong> from the
              database? This action is irreversible.
            </p>

            <div className="flex justify-end gap-2 pt-3 border-t border-hairline">
              <Button type="button" variant="secondary" onClick={() => setAdminDeleteDevice(null)} disabled={saving}>
                Cancel
              </Button>
              <Button
                type="button"
                onClick={handleAdminApproveDelete}
                disabled={saving}
                className="font-bold bg-high-fg hover:bg-high-fg/90 text-white"
              >
                {saving ? "Purging..." : "Permanently Delete"}
              </Button>
            </div>
          </div>
        </Dialog>
      )}
    </div>
  );
}
