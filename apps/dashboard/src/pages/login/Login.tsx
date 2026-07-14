import { useState } from "react";
import type { FormEvent } from "react";
import { PawPrint } from "lucide-react";
import { signIn } from "../../lib/useAuth.ts";
import { Button } from "../../components/ui/button.tsx";
import { Input, Label } from "../../components/ui/input.tsx";

export function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
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
    <div className="flex min-h-screen items-center justify-center bg-bg px-4">
      <div className="w-full max-w-sm rounded-lg border border-hairline bg-surface p-8 shadow-card">
        <div className="mb-1 flex items-center justify-center gap-2 text-2xl font-extrabold text-brand-ink">
          <PawPrint className="text-brand" size={24} />
          FurFeel
        </div>
        <p className="mb-6 mt-0 text-center text-sm text-ink-muted">
          Welcome back — your patients are waiting.
        </p>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4 text-left">
          <div className="flex flex-col gap-1">
            <Label htmlFor="login-email">Email</Label>
            <Input
              id="login-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              required
            />
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="login-password">Password</Label>
            <Input
              id="login-password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </div>
          {error && (
            <p role="alert" className="m-0 rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
              {error}
            </p>
          )}
          <Button type="submit" disabled={submitting}>
            {submitting ? "Signing in..." : "Sign in"}
          </Button>
        </form>
      </div>
    </div>
  );
}
