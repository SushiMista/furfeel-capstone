import type { HTMLAttributes } from "react";
import { cn } from "../../lib/cn.ts";

// ADDED: loading skeletons so pages never flash bare "Loading..." text.
export function Skeleton({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn("animate-pulse rounded-md bg-surface-alt", className)}
      aria-hidden="true"
      {...props}
    />
  );
}

export function CardSkeleton({ lines = 3 }: { lines?: number }) {
  return (
    <div className="rounded-lg border border-hairline bg-surface p-5 shadow-card">
      <Skeleton className="mb-4 h-5 w-1/3" />
      {Array.from({ length: lines }, (_, i) => (
        <Skeleton key={i} className="mb-2 h-4 w-full last:mb-0" />
      ))}
    </div>
  );
}
