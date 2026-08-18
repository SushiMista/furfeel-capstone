import * as React from "react";
import { cn } from "../../lib/cn.ts";

export interface AttachmentProps extends React.ComponentProps<"div"> {
  orientation?: "horizontal" | "vertical";
}

export function Attachment({
  orientation = "horizontal",
  className,
  children,
  ...props
}: AttachmentProps) {
  return (
    <div
      className={cn(
        "relative flex border border-hairline bg-surface rounded-lg p-2.5 shadow-sm transition-colors duration-fast hover:border-brand-soft",
        orientation === "vertical" ? "flex-col gap-2 w-full" : "items-center gap-3 w-full",
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}

export function AttachmentGroup({
  className,
  children,
  ...props
}: React.ComponentProps<"div">) {
  return (
    <div className={cn("flex flex-col gap-2 w-full", className)} {...props}>
      {children}
    </div>
  );
}

export function AttachmentMedia({
  variant = "file",
  className,
  children,
  ...props
}: React.ComponentProps<"div"> & { variant?: "file" | "image" }) {
  return (
    <div
      className={cn(
        "overflow-hidden rounded-md flex-shrink-0 bg-surface-alt flex items-center justify-center",
        variant === "image" ? "w-12 h-12 relative" : "w-10 h-10",
        className
      )}
      {...props}
    >
      {children}
    </div>
  );
}

export function AttachmentContent({
  className,
  children,
  ...props
}: React.ComponentProps<"div">) {
  return (
    <div className={cn("flex-1 min-w-0 flex flex-col gap-0.5", className)} {...props}>
      {children}
    </div>
  );
}

export function AttachmentTitle({
  className,
  children,
  ...props
}: React.ComponentProps<"div">) {
  return (
    <div className={cn("text-sm font-semibold text-ink truncate leading-none", className)} {...props}>
      {children}
    </div>
  );
}

export function AttachmentDescription({
  className,
  children,
  ...props
}: React.ComponentProps<"div">) {
  return (
    <div className={cn("text-xs text-ink-muted truncate leading-none", className)} {...props}>
      {children}
    </div>
  );
}

export function AttachmentActions({
  className,
  children,
  ...props
}: React.ComponentProps<"div">) {
  return (
    <div className={cn("relative z-10 flex items-center gap-1 flex-shrink-0 ml-auto", className)} {...props}>
      {children}
    </div>
  );
}

export function AttachmentAction({
  className,
  children,
  ...props
}: React.ComponentProps<"button">) {
  return (
    <button
      type="button"
      className={cn(
        "inline-flex h-7 w-7 items-center justify-center rounded-md text-ink-muted hover:bg-surface-alt hover:text-ink transition-colors duration-fast",
        className
      )}
      {...props}
    >
      {children}
    </button>
  );
}

export function AttachmentTrigger({ render }: { render: React.ReactElement }) {
  return React.cloneElement(render, {
    className: cn(render.props.className, "absolute inset-0 z-0"),
  });
}
