// ADDED: vet account + settings (docs/05: "account menu + settings (theme,
// profile photo via users.avatar_path, sign out)"). Backed by the same
// user_settings row the mobile app uses, so preferences follow the person.
import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { supabase } from "./supabaseClient.ts";
import { useAuth } from "./useAuth.ts";
import type { User, UserSettings } from "../../../../packages/shared/types/index.ts";

export type ThemeSetting = UserSettings["theme"];

export async function fetchMyProfile(client: SupabaseClient, userId: string): Promise<User | null> {
  const { data, error } = await client
    .from("users")
    .select("id, name, email, role, clinic_id, avatar_path, created_at")
    .eq("id", userId)
    .maybeSingle();
  if (error) throw error;
  return data as unknown as User | null;
}

export async function fetchMyTheme(client: SupabaseClient, userId: string): Promise<ThemeSetting> {
  const { data, error } = await client
    .from("user_settings")
    .select("theme")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return (data?.theme as ThemeSetting) ?? "system";
}

export async function saveMyTheme(
  client: SupabaseClient,
  userId: string,
  theme: ThemeSetting,
): Promise<void> {
  const { error } = await client
    .from("user_settings")
    .upsert({ user_id: userId, theme, updated_at: new Date().toISOString() });
  if (error) throw error;
}

export async function uploadMyAvatar(
  client: SupabaseClient,
  userId: string,
  file: File,
): Promise<string> {
  const extension = file.name.includes(".") ? file.name.split(".").pop() : "jpg";
  const path = `${userId}/avatar.${extension}`;
  const { error: uploadError } = await client.storage
    .from("avatars")
    .upload(path, file, { upsert: true });
  if (uploadError) throw uploadError;
  const { error } = await client.from("users").update({ avatar_path: path }).eq("id", userId);
  if (error) throw error;
  return path;
}

export async function getAvatarSignedUrl(client: SupabaseClient, path: string): Promise<string> {
  const { data, error } = await client.storage.from("avatars").createSignedUrl(path, 3600);
  if (error) throw error;
  return data.signedUrl;
}

/** Applies a theme to the document: explicit choices stamp data-theme; 'system'
 * clears it so the prefers-color-scheme block in tokens.css takes over. */
export function applyTheme(theme: ThemeSetting) {
  if (theme === "system") {
    delete document.documentElement.dataset.theme;
  } else {
    document.documentElement.dataset.theme = theme;
  }
}

export interface AccountState {
  profile: User | null;
  avatarUrl: string | null;
  theme: ThemeSetting;
  setTheme: (theme: ThemeSetting) => void;
  changeAvatar: (file: File) => Promise<void>;
}

/** Profile + theme for the signed-in vet. Theme applies to the document
 * immediately (optimistically) and persists to user_settings behind it. */
export function useAccount(): AccountState {
  const { session } = useAuth();
  const userId = session?.user.id;
  const [profile, setProfile] = useState<User | null>(null);
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [theme, setThemeState] = useState<ThemeSetting>("system");

  useEffect(() => {
    if (!userId) {
      setProfile(null);
      setAvatarUrl(null);
      applyTheme("system");
      return;
    }
    let cancelled = false;
    fetchMyProfile(supabase, userId)
      .then(async (p) => {
        if (cancelled) return;
        setProfile(p);
        if (p?.avatar_path) {
          const url = await getAvatarSignedUrl(supabase, p.avatar_path);
          if (!cancelled) setAvatarUrl(url);
        }
      })
      .catch(() => {});
    fetchMyTheme(supabase, userId)
      .then((t) => {
        if (cancelled) return;
        setThemeState(t);
        applyTheme(t);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [userId]);

  const setTheme = useCallback(
    (next: ThemeSetting) => {
      setThemeState(next);
      applyTheme(next);
      if (userId) saveMyTheme(supabase, userId, next).catch(() => {});
    },
    [userId],
  );

  const changeAvatar = useCallback(
    async (file: File) => {
      if (!userId) return;
      const path = await uploadMyAvatar(supabase, userId, file);
      const url = await getAvatarSignedUrl(supabase, path);
      setProfile((p) => (p ? { ...p, avatar_path: path } : p));
      setAvatarUrl(url);
    },
    [userId],
  );

  return { profile, avatarUrl, theme, setTheme, changeAvatar };
}
