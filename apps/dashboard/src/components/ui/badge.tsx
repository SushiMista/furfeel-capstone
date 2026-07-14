import type { HTMLAttributes } from "react";
import { cn } from "../../lib/cn.ts";

const VARIANTS = {
  default: "bg-brand-soft text-brand-strong",
  neutral: "bg-surface-alt text-ink-muted",
  outline: "border border-hairline text-ink-muted",
} as const;

export function Badge({
  className,
  variant = "default",
  ...props
}: HTMLAttributes<HTMLSpanElement> & { variant?: keyof typeof VARIANTS }) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-pill px-2.5 py-0.5 text-xs font-semibold",
        VARIANTS[variant],
        className,
      )}
      {...props}
    />
  );
}
