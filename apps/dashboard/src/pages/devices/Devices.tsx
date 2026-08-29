import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { Eye } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { fetchDevicesReadOnly, type DeviceWithDog } from "../../lib/queries.ts";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { Badge } from "../../components/ui/badge.tsx";
import { Dialog } from "../../components/ui/dialog.tsx";
import { Button } from "../../components/ui/button.tsx";
import { formatPhilippineTime } from "../../lib/time.ts";

const STATUS_BADGE: Record<string, "default" | "neutral" | "outline"> = {
  active: "default",
  offline: "outline",
  inactive: "neutral",
  maintenance: "neutral",
};

/** Devices tab (docs/05): view-only fleet list for vets/staff -- no register,
 * assign, or delete controls here. Device management stays admin-only
 * (Admin → Devices); devices_select_owner_or_clinic RLS is the real read
 * scope, this page just doesn't render any write UI on top of it. */
export function Devices() {
  const [searchParams] = useSearchParams();
  const [devices, setDevices] = useState<DeviceWithDog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [viewingDevice, setViewingDevice] = useState<DeviceWithDog | null>(null);

  const load = useCallback(async () => {
    try {
      setDevices(await fetchDevicesReadOnly(supabase));
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

  // Auto-open device details modal if target params exist
  useEffect(() => {
    const targetCode = searchParams.get("device_code");
    const targetId = searchParams.get("device_id");
    const targetDogId = searchParams.get("dog_id");

    if (devices.length === 0) return;

    let match: DeviceWithDog | undefined;
    if (targetCode) {
      match = devices.find((d) => d.device_code.toLowerCase() === targetCode.toLowerCase());
    } else if (targetId) {
      match = devices.find((d) => d.id === targetId);
    } else if (targetDogId) {
      match = devices.find((d) => d.dog_id === targetDogId);
    }

    if (match) {
      setViewingDevice(match);
    }
  }, [devices, searchParams]);

  if (loading) return <CardSkeleton lines={6} />;
  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );

  return (
    <div className="flex flex-col gap-5">
      <h1 className="m-0 text-2xl font-bold text-ink">Devices</h1>
      <Card>
        <CardHeader>
          <CardTitle>Harness fleet</CardTitle>
          <CardDescription>
            Every device linked to your dogs or clinic. View-only — registration and
            assignment are managed in Admin.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {devices.length === 0 ? (
            <EmptyState>No devices linked yet 🐾</EmptyState>
          ) : (
            <Table>
              <THead>
                <Tr className="border-t-0">
                  <Th>Code</Th>
                  <Th>Status</Th>
                  <Th>Assigned dog</Th>
                  <Th>Battery</Th>
                  <Th>Firmware</Th>
                  <Th>Last seen</Th>
                  <Th>Actions</Th>
                </Tr>
              </THead>
              <TBody>
                {devices.map((d) => (
                  <Tr key={d.id}>
                    <Td className="font-semibold">{d.device_code}</Td>
                    <Td>
                      <Badge variant={STATUS_BADGE[d.status] ?? "neutral"} className="capitalize">
                        {d.status}
                      </Badge>
                    </Td>
                    <Td className="text-ink-muted">{d.dog?.name ?? "— unassigned —"}</Td>
                    <Td className="tabular-nums">
                      {d.battery_percent != null ? `${d.battery_percent}%` : "—"}
                    </Td>
                    <Td className="text-ink-muted">{d.firmware_version ?? "—"}</Td>
                    <Td className="text-xs text-ink-muted">
                      {d.last_seen_at ? new Date(d.last_seen_at).toLocaleString() : "never"}
                    </Td>
                    <Td>
                      <button
                        type="button"
                        aria-label={`View details for ${d.device_code}`}
                        title="View Device Details"
                        onClick={() => setViewingDevice(d)}
                        className="flex h-8 w-8 items-center justify-center rounded-md bg-surface-alt text-ink-muted transition-colors duration-fast hover:bg-brand-soft hover:text-brand-strong"
                      >
                        <Eye size={15} />
                      </button>
                    </Td>
                  </Tr>
                ))}
              </TBody>
            </Table>
          )}
        </CardContent>
      </Card>

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
                  <Badge variant={STATUS_BADGE[viewingDevice.status] ?? "neutral"} className="capitalize">
                    {viewingDevice.status}
                  </Badge>
                </div>
              </div>

              <div className="flex flex-col gap-1">
                <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Firmware Version</span>
                <span className="text-sm font-medium text-ink">{viewingDevice.firmware_version ?? "—"}</span>
              </div>

              <div className="flex flex-col gap-1">
                <span className="text-xs font-semibold uppercase tracking-wider text-ink-muted">Assigned Dog</span>
                <span className="text-sm font-medium text-ink">
                  {viewingDevice.dog?.name ?? "— unassigned —"}
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
            </div>
          </div>
        )}
      </Dialog>
    </div>
  );
}

