import type { ReactNode } from "react";
import { NavLink } from "react-router-dom";
import {
  Bell,
  FileText,
  LayoutDashboard,
  PawPrint,
  Settings,
  Table2,
} from "lucide-react";
import { useAuth } from "../lib/useAuth.ts";
import { useCurrentRole } from "../lib/useCurrentRole.ts";
import { cn } from "../lib/cn.ts";
import { AccountMenu } from "./AccountMenu.tsx";

const NAV = [
  { to: "/", label: "Overview", icon: LayoutDashboard, end: true },
  { to: "/board", label: "Monitoring board", icon: Table2 },
  { to: "/alerts", label: "Alerts", icon: Bell },
  { to: "/reports", label: "Reports", icon: FileText },
];

/** Dashboard chrome (docs/19 §7): left sidebar — Overview, Board, Alerts, Reports,
 * Admin (admin role only). Clinical, crisp, blue + white. */
export function AppShell({ children }: { children: ReactNode }) {
  const { session } = useAuth();
  const { role } = useCurrentRole();

  return (
    <div className="flex min-h-screen">
      <aside className="print-hidden sticky top-0 flex h-screen w-56 flex-shrink-0 flex-col border-r border-hairline bg-surface px-3 py-5">
        <div className="mb-6 flex items-center gap-2 px-2 text-lg font-extrabold text-brand-ink">
          <PawPrint size={20} className="text-brand" />
          FurFeel
        </div>
        <nav className="flex flex-col gap-1" aria-label="Main">
          {NAV.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                cn(
                  "flex items-center gap-2.5 rounded-md px-3 py-2 text-sm font-medium",
                  "transition-colors duration-fast",
                  isActive
                    ? "bg-brand-soft text-brand-strong"
                    : "text-ink-muted hover:bg-surface-alt hover:text-ink",
                )
              }
            >
              <Icon size={16} />
              {label}
            </NavLink>
          ))}
          {role === "admin" && (
            <NavLink
              to="/admin"
              className={({ isActive }) =>
                cn(
                  "flex items-center gap-2.5 rounded-md px-3 py-2 text-sm font-medium",
                  "transition-colors duration-fast",
                  isActive
                    ? "bg-brand-soft text-brand-strong"
                    : "text-ink-muted hover:bg-surface-alt hover:text-ink",
                )
              }
            >
              <Settings size={16} />
              Admin
            </NavLink>
          )}
        </nav>
        {/* ADDED: account menu (docs/05) — theme, profile photo, sign out. */}
        <div className="mt-auto border-t border-hairline pt-3">
          <AccountMenu email={session?.user.email ?? ""} />
        </div>
      </aside>
      <main className="min-w-0 flex-1 px-8 py-6">
        <div className="mx-auto max-w-6xl">{children}</div>
      </main>
    </div>
  );
}
