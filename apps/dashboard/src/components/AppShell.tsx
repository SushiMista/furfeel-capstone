import { useCallback, useEffect, useState, type ReactNode } from "react";
import { NavLink, useLocation } from "react-router-dom";
import {
  Activity,
  ArrowLeftRight,
  Bell,
  Building2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Cpu,
  FileText,
  LayoutDashboard,
  PawPrint,
  Radio,
  ShieldCheck,
  Table2,
  Users,
} from "lucide-react";
import { useAuth } from "../lib/useAuth.ts";
import { useCurrentRole } from "../lib/useCurrentRole.ts";
import { cn } from "../lib/cn.ts";
import { AccountMenu } from "./AccountMenu.tsx";
import { supabase } from "../lib/supabaseClient.ts";
import { useToast } from "./ui/toast.tsx";
import { ImageAttachmentNotification } from "./ImageAttachmentNotification.tsx";
import { fetchAlertsQueue, fetchDog, getMediaSignedUrl } from "../lib/queries.ts";

interface NavItem {
  to: string;
  label: string;
  icon: typeof LayoutDashboard;
  end?: boolean;
}

interface NavGroup {
  id: string;
  label: string;
  adminOnly?: boolean;
  items: NavItem[];
}

const NAV_GROUPS: NavGroup[] = [
  {
    id: "clinical",
    label: "Clinical Operations",
    items: [
      { to: "/", label: "Overview", icon: LayoutDashboard, end: true },
      { to: "/board", label: "Monitoring board", icon: Table2 },
      { to: "/alerts", label: "Alerts queue", icon: Bell },
      { to: "/handover", label: "Handover notes", icon: ArrowLeftRight },
    ],
  },
  {
    id: "fleet",
    label: "Fleet & Telemetry",
    items: [
      { to: "/devices", label: "Device fleet", icon: Radio },
      { to: "/reports", label: "Analytics & reports", icon: FileText },
    ],
  },
  {
    id: "admin",
    label: "Admin Console",
    adminOnly: true,
    items: [
      { to: "/admin/users", label: "User accounts", icon: Users },
      { to: "/admin/clinics", label: "Partner clinics", icon: Building2 },
      { to: "/admin/devices", label: "Device management", icon: Cpu },
      { to: "/admin/audit", label: "Audit logs", icon: ShieldCheck },
      { to: "/admin/health", label: "System health", icon: Activity },
    ],
  },
];

/** Dashboard chrome: collapsible nested sidebar navigation with accordion groups,
 * logo header, PST alert badge counters, and state persistence. */
export function AppShell({ children }: { children: ReactNode }) {
  const { session } = useAuth();
  const { role } = useCurrentRole();
  const location = useLocation();
  const isDogPage = location.pathname.startsWith("/dogs/");
  const toast = useToast();

  const [isCollapsed, setIsCollapsed] = useState<boolean>(() => {
    return localStorage.getItem("furfeel:sidebar-collapsed") === "true";
  });

  const [openGroups, setOpenGroups] = useState<Record<string, boolean>>({
    clinical: true,
    fleet: true,
    admin: true,
  });

  const [openAlertCount, setOpenAlertCount] = useState<number>(0);

  const toggleCollapse = useCallback(() => {
    setIsCollapsed((prev) => {
      const next = !prev;
      localStorage.setItem("furfeel:sidebar-collapsed", String(next));
      return next;
    });
  }, []);

  const toggleGroup = (groupId: string) => {
    setOpenGroups((prev) => ({
      ...prev,
      [groupId]: !prev[groupId],
    }));
  };

  // Fetch open alerts count for badge display
  useEffect(() => {
    if (!session) return;
    fetchAlertsQueue(supabase, "open")
      .then((openAlerts) => setOpenAlertCount(openAlerts.length))
      .catch(() => {});
  }, [session, location.pathname]);

  // Global realtime media submission toast
  useEffect(() => {
    if (!session) return;

    const channel = supabase
      .channel("media_submissions_global")
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "media_submissions",
        },
        async (payload) => {
          try {
            const submission = payload.new;
            const dog = await fetchDog(supabase, submission.dog_id);
            if (!dog) return;

            const imageUrl = await getMediaSignedUrl(supabase, submission.storage_path, 3600);

            toast(
              "info",
              <ImageAttachmentNotification
                dogId={dog.id}
                dogName={dog.name}
                imageUrl={imageUrl}
                fileName={submission.storage_path.split("/").pop() || "photo.jpg"}
                metaText="New Upload"
              />,
            );
          } catch (err) {
            console.error("Failed to process realtime media submission:", err);
          }
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [session, toast]);

  return (
    <div className="flex min-h-screen bg-surface">
      {/* Collapsible Sidebar */}
      <aside
        className={cn(
          "print-hidden fixed top-0 left-0 bottom-0 z-30 flex h-screen flex-col border-r border-hairline bg-surface px-3 py-4",
          "transition-all duration-300 ease-in-out",
          isCollapsed ? "w-16" : "w-64",
        )}
      >
        {/* Floating Outer Edge Hanging Toggle Button */}
        <button
          type="button"
          onClick={toggleCollapse}
          title={isCollapsed ? "Expand sidebar" : "Collapse sidebar"}
          aria-label={isCollapsed ? "Expand sidebar" : "Collapse sidebar"}
          className={cn(
            "absolute -right-3 top-5 z-40 flex h-6 w-6 items-center justify-center rounded-full border border-hairline bg-surface text-ink-muted shadow-md transition-all duration-fast",
            "hover:bg-brand-soft hover:text-brand-strong hover:scale-110 hover:border-brand/40",
          )}
        >
          {isCollapsed ? <ChevronRight size={13} /> : <ChevronLeft size={13} />}
        </button>

        {/* Header: Logo */}
        <div className="mb-5 flex items-center border-b border-hairline pb-3 px-1">
          {isCollapsed ? (
            <div className="flex w-full justify-center">
              <div className="flex h-9 w-9 items-center justify-center rounded-md bg-brand-soft text-brand font-bold shadow-xs">
                <PawPrint size={20} />
              </div>
            </div>
          ) : (
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-md bg-brand-soft text-brand font-bold shadow-xs">
                <PawPrint size={20} />
              </div>
              <div className="flex flex-col min-w-0">
                <span className="text-base font-extrabold text-brand-ink truncate">FurFeel</span>
                <span className="text-[10px] font-semibold text-ink-muted uppercase tracking-wider truncate">
                  Clinical &amp; Fleet Ops
                </span>
              </div>
            </div>
          )}
        </div>

        {/* Nested Navigation Accordions */}
        <nav className="flex flex-1 flex-col gap-4 overflow-y-auto pr-1" aria-label="Main navigation">
          {NAV_GROUPS.map((group) => {
            if (group.adminOnly && role !== "admin") return null;
            const isOpen = openGroups[group.id] ?? true;

            return (
              <div key={group.id} className="flex flex-col gap-1">
                {/* Accordion Header (Expanded mode) */}
                {!isCollapsed ? (
                  <button
                    type="button"
                    onClick={() => toggleGroup(group.id)}
                    className="flex w-full items-center justify-between px-2 py-1 text-xs font-bold uppercase tracking-wider text-ink-muted hover:text-ink transition-colors duration-fast"
                  >
                    <span>{group.label}</span>
                    {isOpen ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                  </button>
                ) : (
                  <div className="h-px bg-hairline my-1" />
                )}

                {/* Sub-items List */}
                {(isCollapsed || isOpen) && (
                  <div className={cn("flex flex-col gap-1", !isCollapsed && "pl-1")}>
                    {group.items.map(({ to, label, icon: Icon, end }) => (
                      <NavLink
                        key={to}
                        to={to}
                        end={end}
                        title={isCollapsed ? label : undefined}
                        className={({ isActive }) =>
                          cn(
                            "flex items-center gap-2.5 rounded-md text-sm font-medium transition-colors duration-fast",
                            isCollapsed ? "justify-center p-2" : "px-3 py-2",
                            isActive
                              ? "bg-brand-soft text-brand-strong font-semibold"
                              : "text-ink-muted hover:bg-surface-alt hover:text-ink",
                          )
                        }
                      >
                        <div className="relative flex items-center justify-center">
                          <Icon size={18} className="flex-shrink-0" />
                          {to === "/alerts" && openAlertCount > 0 && isCollapsed && (
                            <span className="absolute -top-1.5 -right-2.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-high-soft px-1 text-[10px] font-extrabold tabular-nums text-high-fg ring-2 ring-surface shadow-2xs">
                              {openAlertCount}
                            </span>
                          )}
                        </div>

                        {!isCollapsed && <span className="truncate flex-1">{label}</span>}

                        {/* Live Alert Count Badge (Expanded Mode) */}
                        {to === "/alerts" && openAlertCount > 0 && !isCollapsed && (
                          <span className="rounded-pill bg-high-soft px-2 py-0.5 text-xs font-bold tabular-nums text-high-fg">
                            {openAlertCount}
                          </span>
                        )}
                      </NavLink>
                    ))}
                  </div>
                )}
              </div>
            );
          })}
        </nav>

        {/* Account Menu Footer */}
        <div className="mt-auto border-t border-hairline pt-3">
          <AccountMenu email={session?.user.email ?? ""} isCollapsed={isCollapsed} />
        </div>
      </aside>

      {/* Main Content Area */}
      <main
        className={cn(
          "min-w-0 flex-1 transition-all duration-300 ease-in-out",
          isCollapsed ? "ml-16" : "ml-64",
          !isDogPage && "px-8 py-6",
        )}
      >
        <div className={cn(!isDogPage && "mx-auto max-w-6xl")}>{children}</div>
      </main>
    </div>
  );
}
