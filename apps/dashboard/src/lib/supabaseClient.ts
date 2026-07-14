import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!url || !anonKey) {
  throw new Error(
    "VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be set (see .env.example). " +
      "Only the anon key belongs in a client -- never the service role key.",
  );
}

// Anon-key client only: every query goes through the signed-in user's RLS policies.
export const supabase = createClient(url, anonKey);
