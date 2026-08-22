import { useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { supabase } from "./supabaseClient.ts";
import { fetchCurrentUserRole } from "./queries.ts";

export interface AuthState {
  session: Session | null;
  loading: boolean;
}

/** Tracks the current Supabase Auth session. Auth itself is handled entirely by the
 * Supabase Auth SDK (docs/10: "No custom endpoints needed"); this just exposes the
 * session to components so pages can gate on it and RLS-scoped queries have a user. */
export function useAuth(): AuthState {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    supabase.auth.getSession().then(({ data }) => {
      if (cancelled) return;
      setSession(data.session);
      setLoading(false);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
      setLoading(false);
    });

    return () => {
      cancelled = true;
      subscription.subscription.unsubscribe();
    };
  }, []);

  return { session, loading };
}

export async function signIn(email: string, password: string) {
  const res = await supabase.auth.signInWithPassword({ email, password });
  if (res.error) return res;

  const userId = res.data.session?.user.id;
  if (userId) {
    try {
      const role = await fetchCurrentUserRole(supabase, userId);
      if (role === "owner") {
        await supabase.auth.signOut();
        return {
          data: { user: null, session: null },
          error: {
            name: "AuthApiError",
            status: 403,
            message:
              "Access Denied: Dog owner accounts are restricted to the FurFeel Mobile App. Please log in using the mobile application.",
          },
        };
      }
    } catch {
      // Role fetch error fallback — allow authentication to proceed or handle safely
    }
  }

  return res;
}

export async function signOut() {
  return supabase.auth.signOut();
}
