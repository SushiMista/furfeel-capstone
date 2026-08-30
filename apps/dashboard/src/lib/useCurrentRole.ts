import { useEffect, useState } from "react";
import { supabase } from "./supabaseClient.ts";
import { fetchCurrentUserProfile, type CurrentUserProfile } from "./queries.ts";
import { useAuth } from "./useAuth.ts";

export interface UserRoleState {
  role: string | null;
  clinicId: string | null;
  name: string | null;
  email: string | null;
  loading: boolean;
}

/** The signed-in user's public.users profile and role — used to gate UI features
 * and isolate multi-tenant clinic operations to their own clinic. */
export function useCurrentRole(): UserRoleState {
  const { session } = useAuth();
  const [profile, setProfile] = useState<CurrentUserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const userId = session?.user.id;
    if (!userId) {
      setProfile(null);
      setLoading(false);
      return;
    }
    let cancelled = false;
    fetchCurrentUserProfile(supabase, userId)
      .then((p) => {
        if (!cancelled) setProfile(p);
      })
      .catch(() => {
        if (!cancelled) setProfile(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [session?.user.id]);

  return {
    role: profile?.role ?? null,
    clinicId: profile?.clinicId ?? null,
    name: profile?.name ?? null,
    email: profile?.email ?? null,
    loading,
  };
}

