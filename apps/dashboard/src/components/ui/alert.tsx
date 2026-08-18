import * as React from "react";
import { cn } from "../../lib/cn.ts";

export function Alert({
  className,
  children,
  ...props
}: React.ComponentProps<"div">) {
  return (
    <div
      role="alert"
      className={cn(
        "relative w-full rounded-lg border border-hairline bg-surface p-4 text-sm flex items-start gap-3 shadow-sm",
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}

export function AlertTitle({
  className,
  children,
  ...props
}: React.ComponentProps<"h5">) {
  return (
    <h5
      className={cn("font-semibold text-ink leading-none tracking-tight mb-1", className)}
      {...props}
    >
      {children}
    </h5>
  );
}

export function AlertDescription({
  className,
  children,
  ...props
}: React.ComponentProps<"div">) {
  return (
    <div
      className={cn("text-xs text-ink-muted leading-relaxed [&_p]:leading-relaxed", className)}
      {...props}
    >
      {children}
    </div>
  );
}
