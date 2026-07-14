import { useCallback, useEffect, useState } from "react";
import type { FormEvent } from "react";
import { supabase } from "../lib/supabaseClient.ts";
import {
  addVetNote,
  fetchCurrentUserRole,
  fetchVetNotes,
  type VetNoteWithAuthor,
} from "../lib/queries.ts";
import { useAuth } from "../lib/useAuth.ts";
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card.tsx";
import { Button } from "./ui/button.tsx";
import { Textarea } from "./ui/input.tsx";
import { EmptyState } from "./ui/empty-state.tsx";
import { useToast } from "./ui/toast.tsx";

const STAFF_ROLES = ["vet_staff", "veterinarian", "admin"];

/** Vet review notes (docs/05). The add form is offered only to clinic staff roles as a
 * UX nicety — RLS (vet_notes_insert_clinic_staff) is the real gate either way. */
export function VetNotes({ dogId }: { dogId: string }) {
  const { session } = useAuth();
  const toast = useToast();
  const [notes, setNotes] = useState<VetNoteWithAuthor[]>([]);
  const [role, setRole] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    try {
      const userId = session?.user.id;
      const [noteRows, userRole] = await Promise.all([
        fetchVetNotes(supabase, dogId),
        userId ? fetchCurrentUserRole(supabase, userId) : Promise.resolve(null),
      ]);
      setNotes(noteRows);
      setRole(userRole);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load notes");
    }
  }, [dogId, session?.user.id]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    const userId = session?.user.id;
    const note = draft.trim();
    if (!userId || !note) return;
    setSubmitting(true);
    setError(null);
    try {
      await addVetNote(supabase, dogId, userId, note);
      setDraft("");
      toast("success", "Note saved");
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save the note");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Vet notes</CardTitle>
      </CardHeader>
      <CardContent>
        {role !== null && STAFF_ROLES.includes(role) && (
          <form className="mb-4 flex flex-col items-start gap-3" onSubmit={handleSubmit}>
            <Textarea
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              placeholder="Add a review note for this dog…"
              rows={3}
            />
            <Button type="submit" disabled={submitting || draft.trim().length === 0}>
              {submitting ? "Saving…" : "Add note"}
            </Button>
          </form>
        )}
        {error && (
          <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
            {error}
          </p>
        )}
        {notes.length === 0 ? (
          <EmptyState>No notes yet — observations will collect here 🐾</EmptyState>
        ) : (
          <ul className="m-0 flex list-none flex-col gap-3 p-0">
            {notes.map((n) => (
              <li key={n.id} className="rounded-md bg-surface-alt p-4">
                <p className="m-0 mb-1 text-sm text-ink">{n.note}</p>
                <p className="m-0 text-xs text-ink-muted">
                  {n.author?.name ?? "Clinic staff"} · {new Date(n.created_at).toLocaleString()}
                </p>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}
