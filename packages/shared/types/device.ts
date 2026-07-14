export type DeviceStatus = "active" | "inactive" | "offline" | "maintenance";

/** devices row shape, client-safe subset (docs/09 Database Schema). Deliberately omits
 * ingest_key_hash -- that column must never be selected by a client (see the pending
 * column-grant migration restricting it at the DB level). */
export interface Device {
  id: string;
  dog_id: string | null;
  device_code: string;
  status: DeviceStatus;
  last_seen_at: string | null;
  firmware_version: string | null;
  created_at: string;
}
