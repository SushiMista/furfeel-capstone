// ADDED: vet account menu (docs/05): avatar + name, with theme setting,
// profile-photo upload, and sign out — so the dashboard is a real signed-in
// product, not an email string in a corner.
import { useEffect, useRef, useState } from "react";
import { Camera, Check, LogOut, Monitor, Moon, Sun } from "lucide-react";
import { signOut } from "../lib/useAuth.ts";
import { useAccount, type ThemeSetting } from "../lib/userSettings.ts";
import { cn } from "../lib/cn.ts";

const THEME_OPTIONS: { value: ThemeSetting; label: string; icon: typeof Sun }[] = [
  { value: "system", label: "System", icon: Monitor },
  { value: "light", label: "Light", icon: Sun },
  { value: "dark", label: "Dark", icon: Moon },
];

function Avatar({ url, name, size = 32 }: { url: string | null; name: string; size?: number }) {
  const initial = name.trim().charAt(0).toUpperCase() || "?";
  return url ? (
    <img
      src={url}
      alt=""
      width={size}
      height={size}
      className="rounded-pill object-cover"
      style={{ width: size, height: size }}
    />
  ) : (
    <span
      className="inline-flex items-center justify-center rounded-pill bg-brand-soft font-bold text-brand"
      style={{ width: size, height: size, fontSize: size * 0.45 }}
      aria-hidden="true"
    >
      {initial}
    </span>
  );
}

export function AccountMenu({ email }: { email: string }) {
  const { profile, avatarUrl, theme, setTheme, changeAvatar } = useAccount();
  const [open, setOpen] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  // Close on outside click / Escape — standard menu behavior.
  useEffect(() => {
    if (!open) return;
    const onPointerDown = (e: PointerEvent) => {
      if (!menuRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  const name = profile?.name ?? email;

  return (
    <div ref={menuRef} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className={cn(
          "flex w-full items-center gap-2.5 rounded-md px-2 py-2 text-left",
          "transition-colors duration-fast hover:bg-surface-alt",
        )}
      >
        <Avatar url={avatarUrl} name={name} />
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-semibold text-ink">{name}</span>
          <span className="block truncate text-xs text-ink-muted">{email}</span>
        </span>
      </button>

      {open && (
        <div
          className={cn(
            "absolute bottom-full left-0 z-20 mb-2 w-60 rounded-lg border border-hairline",
            "bg-surface p-2 shadow-card",
            "motion-safe:animate-[ff-pop_var(--ff-motion-fast)_var(--ff-motion-easing)]",
          )}
        >
          <div className="px-2 pb-2 pt-1">
            <div className="mb-1 text-xs font-semibold uppercase tracking-wide text-ink-muted">
              Theme
            </div>
            <div className="flex gap-1" role="group" aria-label="Theme">
              {THEME_OPTIONS.map(({ value, label, icon: Icon }) => (
                <button
                  key={value}
                  type="button"
                  aria-pressed={theme === value}
                  onClick={() => setTheme(value)}
                  className={cn(
                    "flex flex-1 flex-col items-center gap-1 rounded-md border px-2 py-1.5 text-xs font-medium",
                    "transition-colors duration-fast",
                    theme === value
                      ? "border-brand bg-brand-soft text-brand-strong"
                      : "border-hairline text-ink-muted hover:bg-surface-alt",
                  )}
                >
                  <Icon size={14} aria-hidden="true" />
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div className="my-1 border-t border-hairline" />
          <button
            type="button"
            disabled={uploading}
            onClick={() => fileRef.current?.click()}
            className={cn(
              "flex w-full items-center gap-2.5 rounded-md px-2 py-2 text-sm font-medium text-ink",
              "transition-colors duration-fast hover:bg-surface-alt disabled:opacity-50",
            )}
          >
            <Camera size={15} className="text-ink-muted" aria-hidden="true" />
            <span aria-live="polite">
              {uploading
                ? "Uploading…"
                : uploadError
                  ? "Upload failed — try again"
                  : profile?.avatar_path
                    ? "Replace photo"
                    : "Add profile photo"}
            </span>
            {profile?.avatar_path && !uploading && (
              <Check size={13} className="ml-auto text-calm-fg" aria-hidden="true" />
            )}
          </button>
          <input
            ref={fileRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={async (e) => {
              const file = e.target.files?.[0];
              e.target.value = "";
              if (!file) return;
              setUploading(true);
              setUploadError(false);
              try {
                await changeAvatar(file);
              } catch {
                setUploadError(true);
              } finally {
                setUploading(false);
              }
            }}
          />
          <button
            type="button"
            onClick={() => signOut()}
            className={cn(
              "flex w-full items-center gap-2.5 rounded-md px-2 py-2 text-sm font-medium text-ink",
              "transition-colors duration-fast hover:bg-surface-alt",
            )}
          >
            <LogOut size={15} className="text-ink-muted" aria-hidden="true" />
            Sign out
          </button>
        </div>
      )}
    </div>
  );
}
