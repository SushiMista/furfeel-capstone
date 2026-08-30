import type { ReactNode } from "react";
import { PawPrint } from "lucide-react";
import { cn } from "../../lib/cn.ts";

/** Friendly empty state (docs/19 §7): encouraging copy + a small illustration,
 * never a bare "No data". */
export function EmptyState({
  children,
  icon,
  className,
}: {
  children: ReactNode;
  icon?: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("flex flex-col items-center gap-2 px-5 py-10 text-center", className)}>
      <span className="text-brand/60 flex items-center justify-center h-12 w-12 rounded-full bg-brand-soft" aria-hidden="true">
        {icon ?? <PawPrint size={24} strokeWidth={1.75} />}
      </span>
      <p className="m-0 text-sm text-ink-muted">{children}</p>
    </div>
  );
}
