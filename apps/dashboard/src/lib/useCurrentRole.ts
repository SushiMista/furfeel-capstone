import { useEffect, useState } from "react";
import { supabase } from "./supabaseClient.ts";
import { fetchCurrentUserRole } from "./queries.ts";
import { useAuth } from "./useAuth.ts";

/** The signed-in user's public.users role — used only to decide which UI to show
 * (e.g. the Admin nav item); RLS remains the actual gate on every query/write. */
export function useCurrentRole(): { role: string | null; loading: boolean } {
  const { session } = useAuth();
  const [role, setRole] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const userId = session?.user.id;
    if (!userId) {
      setRole(null);
      setLoading(false);
      return;
    }
    let cancelled = false;
    fetchCurrentUserRole(supabase, userId)
      .then((r) => {
        if (!cancelled) setRole(r);
      })
      .catch(() => {
        if (!cancelled) setRole(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [session?.user.id]);

  return { role, loading };
}
