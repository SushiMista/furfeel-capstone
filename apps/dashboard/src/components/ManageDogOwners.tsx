import { useEffect, useState } from "react";
import type { Dog, User } from "../../../../packages/shared/types/index.ts";
import { supabase } from "../lib/supabaseClient.ts";
import { fetchAllUsers } from "../lib/adminQueries.ts";
import { assignDogOwners, fetchDogOwners } from "../lib/queries.ts";
import { friendlyError } from "../lib/errors.ts";
import { Dialog } from "./ui/dialog.tsx";
import { Button } from "./ui/button.tsx";
import { Input } from "./ui/input.tsx";

export function ManageDogOwners({ dog, owners, onClose, onSaved }: {
  dog: Dog; owners: User[]; onClose: () => void; onSaved: (owners: User[]) => void;
}) {
  const [accounts, setAccounts] = useState<User[]>([]);
  const [selected, setSelected] = useState<string[]>([]);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => {
    let cancelled = false;
    fetchAllUsers(supabase).then((users) => { if (!cancelled) setAccounts(users); })
      .catch((err) => { if (!cancelled) setError(friendlyError(err, "load owner accounts")); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, []);
  const linked = new Set([dog.owner_user_id, ...owners.map((o) => o.id)]);
  const eligible = accounts.filter((u) => u.role === "owner" && !linked.has(u.id));
  const visible = eligible.filter((u) => `${u.name} ${u.email}`.toLowerCase().includes(search.trim().toLowerCase()));
  async function save() {
    setSaving(true); setError("");
    try {
      await assignDogOwners(supabase, dog.id, selected);
      const updated = await fetchDogOwners(supabase, dog.id);
      if (!selected.every((id) => updated.some((u) => u.id === id))) throw new Error("Could not verify the new owner links. Refresh the dog profile before retrying.");
      onSaved(updated);
    } catch (err) { setError(friendlyError(err, "add these owners")); }
    finally { setSaving(false); }
  }
  return <Dialog open title={`Manage owners · ${dog.name}`} onClose={() => { if (!saving) onClose(); }}>
    <div className="max-h-[70dvh] overflow-y-auto space-y-4">
      <p className="text-sm text-ink-muted">Add registered owner accounts to this dog. Existing owners remain linked. Added owners can access this dog's records in the mobile app.</p>
      <div><h3 className="text-sm font-semibold text-ink">Current owners</h3>
        <ul className="mt-2 space-y-1 text-sm text-ink-muted">{owners.map((o) => <li key={o.id}>{o.name} ({o.email})</li>)}</ul>
      </div>
      <Input aria-label="Search owner accounts" placeholder="Search owner name or email" value={search} onChange={(e) => setSearch(e.target.value)} disabled={saving || loading}/>
      {loading ? <p role="status">Loading owner accounts…</p> : <div className="max-h-56 overflow-y-auto space-y-2">
        {visible.map((u) => <label key={u.id} className="flex items-center gap-3 rounded-md border border-hairline p-3 cursor-pointer">
          <input type="checkbox" checked={selected.includes(u.id)} disabled={saving || u.is_active === false} onChange={(e) => setSelected((ids) => e.target.checked ? [...ids, u.id] : ids.filter((id) => id !== u.id))}/>
          <span className="min-w-0 text-sm"><span className="block font-medium text-ink">{u.name}</span><span className="block break-all text-ink-muted">{u.email}</span>{u.is_active === false && <span className="block text-ink-muted">Inactive account — ask an admin to reactivate it in Admin → User Accounts, then reopen this editor.</span>}</span>
        </label>)}
        {visible.length === 0 && <p className="text-sm text-ink-muted">{search ? "No matching owner accounts." : "No additional registered owners available. Ask the user to create an owner account first."}</p>}
      </div>}
      {error && <p role="alert" className="text-sm text-danger">{error}</p>}
      <div className="flex flex-wrap justify-end gap-2"><Button variant="secondary" disabled={saving} onClick={onClose}>Cancel</Button><Button disabled={loading || saving || selected.length === 0} onClick={save}>{saving ? "Saving…" : `Add ${selected.length || ""} owner${selected.length === 1 ? "" : "s"}`}</Button></div>
    </div>
  </Dialog>;
}
