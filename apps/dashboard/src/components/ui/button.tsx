import { forwardRef, type ButtonHTMLAttributes } from "react";
import { cn } from "../../lib/cn.ts";

// shadcn-style button owned in-repo (docs/19 §1) — variants map to token colors only.
const VARIANTS = {
  default: "bg-brand text-surface hover:bg-brand-strong",
  secondary: "bg-brand-soft text-brand-strong hover:brightness-95",
  outline: "border border-hairline bg-surface text-ink hover:bg-surface-alt",
  ghost: "text-ink-muted hover:bg-surface-alt hover:text-ink",
  destructive: "bg-high text-surface hover:brightness-95",
} as const;

const SIZES = {
  default: "h-10 px-4 text-sm",
  sm: "h-8 px-3 text-xs",
  lg: "h-11 px-6 text-sm",
} as const;

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: keyof typeof VARIANTS;
  size?: keyof typeof SIZES;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = "default", size = "default", type = "button", ...props }, ref) => (
    <button
      ref={ref}
      type={type}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-md font-semibold",
        "transition-colors duration-fast disabled:pointer-events-none disabled:opacity-50",
        VARIANTS[variant],
        SIZES[size],
        className,
      )}
      {...props}
    />
  ),
);
Button.displayName = "Button";
