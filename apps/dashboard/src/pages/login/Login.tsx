import { useState } from "react";
import type { FormEvent } from "react";
import { useSearchParams } from "react-router-dom";
import { Eye, EyeOff } from "lucide-react";
import { signIn } from "../../lib/useAuth.ts";
import { Button } from "../../components/ui/button.tsx";
import { Input, Label } from "../../components/ui/input.tsx";

/** Brand panel: a paw with a pulse line running through it, FurFeel in one
 * image. Drawn in code so it follows the brand colour. */
function BrandPanel() {
  return (
    <div className="relative hidden overflow-hidden bg-brand lg:block lg:w-1/2">
      <svg
        viewBox="0 0 240 170"
        aria-hidden="true"
        className="absolute -right-[12%] -top-[4%] w-[105%] fill-white opacity-[.13]"
      >
        <ellipse cx="62" cy="52" rx="15" ry="20" />
        <ellipse cx="100" cy="36" rx="15" ry="21" />
        <ellipse cx="140" cy="36" rx="15" ry="21" />
        <ellipse cx="178" cy="52" rx="15" ry="20" />
        <path d="M120 66c-31 0-58 28-58 56 0 19 14 28 31 26 12-1 18-5 27-5s15 4 27 5c17 2 31-7 31-26 0-28-27-56-58-56z" />
      </svg>
      <svg
        viewBox="0 0 320 60"
        aria-hidden="true"
        className="absolute inset-x-0 top-[42%] w-full fill-none stroke-white opacity-85"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M0 34h104l12-22 18 44 14-30 8 8h164" />
      </svg>
      <h2 className="absolute bottom-14 left-14 m-0 text-5xl font-bold leading-[1.1] tracking-tight text-white">
        Every heartbeat,
        <br />
        in plain sight.
      </h2>
    </div>
  );
}

export function Login() {
  const [searchParams] = useSearchParams();
  const isOwnerRestricted = searchParams.get("error") === "owner_restricted";

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(
    isOwnerRestricted
      ? "Access Denied: Dog owner accounts are restricted to the FurFeel Mobile App. Please log in using the mobile application."
      : null,
  );
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    const { error: signInError } = await signIn(email, password);
    setSubmitting(false);
    if (signInError) setError(signInError.message);
  }

  return (
    <div className="flex min-h-screen">
      {/* Left panel — form */}
      <div className="flex w-full flex-col justify-between px-8 py-10 lg:w-1/2 lg:px-16 xl:px-24">
        {/* Top: logo */}
        <div className="flex items-center gap-2.5">
          <img
            src="/favicon.png"
            alt="FurFeel Logo"
            className="h-9 w-9 rounded-lg object-contain shadow-sm"
          />
          <span className="text-xl font-bold tracking-tight text-ink">
            FurFeel
          </span>
        </div>

        {/* Center: form content */}
        <div className="mx-auto w-full max-w-[400px] ff-enter">
          <h1 className="text-3xl font-bold tracking-tight text-ink">
            Welcome back
          </h1>
          <p className="mt-2 mb-8 text-[15px] text-ink-muted">
            Sign in to monitor your patients — they&apos;re waiting for you.
          </p>

          <form onSubmit={handleSubmit} className="flex flex-col gap-5">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="login-email">Email address</Label>
              <Input
                id="login-email"
                type="email"
                placeholder="vet@clinic.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                autoComplete="email"
                required
                className="h-11"
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="login-password">Password</Label>
              <div className="relative">
                <Input
                  id="login-password"
                  type={showPassword ? "text" : "password"}
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete="current-password"
                  required
                  className="h-11 pr-10"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-muted hover:text-ink transition-colors duration-fast"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            {/* Forgot password row */}
            <div className="flex items-center justify-end text-sm">
              <button
                type="button"
                className="font-medium text-brand hover:text-brand-strong transition-colors duration-fast"
                onClick={() => {
                  /* TODO: Supabase resetPasswordForEmail */
                }}
              >
                Forgot password?
              </button>
            </div>

            {/* Error message */}
            {error && (
              <div
                role="alert"
                className="rounded-md bg-high-soft border border-high/20 px-4 py-3 text-sm text-high-fg leading-relaxed flex items-start gap-2"
              >
                <svg className="mt-0.5 h-4 w-4 shrink-0 text-high" viewBox="0 0 16 16" fill="currentColor">
                  <path d="M8 1a7 7 0 100 14A7 7 0 008 1zm-.75 3.75a.75.75 0 011.5 0v3.5a.75.75 0 01-1.5 0v-3.5zM8 11a1 1 0 100 2 1 1 0 000-2z" />
                </svg>
                <span>{error}</span>
              </div>
            )}

            {/* Submit button */}
            <Button
              type="submit"
              disabled={submitting}
              className="h-11 text-[15px] font-semibold shadow-sm"
            >
              {submitting ? (
                <span className="flex items-center gap-2">
                  <svg className="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  Signing in…
                </span>
              ) : (
                "Sign in"
              )}
            </Button>
          </form>
        </div>

        {/* Bottom: footer note */}
        <p className="text-center text-xs text-ink-muted lg:text-left">
          Veterinary Dashboard — Decision support, not diagnosis.
        </p>
      </div>

      <BrandPanel />
    </div>
  );
}
