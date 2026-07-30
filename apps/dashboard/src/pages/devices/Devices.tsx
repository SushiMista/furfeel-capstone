import { friendlyError } from "../../lib/errors.ts";
import { useCallback, useEffect, useState } from "react";
import { supabase } from "../../lib/supabaseClient.ts";
import { fetchDevicesReadOnly, type DeviceWithDog } from "../../lib/queries.ts";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Table, TBody, Td, Th, THead, Tr } from "../../components/ui/table.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { Badge } from "../../components/ui/badge.tsx";

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
  const [devices, setDevices] = useState<DeviceWithDog[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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
                  </Tr>
                ))}
              </TBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
