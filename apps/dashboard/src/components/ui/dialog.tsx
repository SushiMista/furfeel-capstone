// ADDED: minimal controlled dialog (confirm flows, Admin forms) — no portal library,
// Escape + backdrop close, focus ring from tokens. Backdrop blur + fade/scale-in
// transition on mount (no exit animation — closes instantly, kept lazy).
import { useEffect, useState, type ReactNode } from "react";
import { X } from "lucide-react";
import { Button } from "./button.tsx";
import { cn } from "../../lib/cn.ts";

export function Dialog({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}) {
  const [show, setShow] = useState(false);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    const raf = requestAnimationFrame(() => setShow(true));
    return () => {
      window.removeEventListener("keydown", onKey);
      cancelAnimationFrame(raf);
      setShow(false);
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      className={cn(
        "fixed inset-0 z-40 flex items-center justify-center bg-ink/40 backdrop-blur-sm p-4",
        "transition-opacity duration-fast",
        show ? "opacity-100" : "opacity-0",
      )}
      onClick={onClose}
      role="presentation"
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={cn(
          "w-full max-w-lg rounded-lg border border-hairline bg-surface p-5 shadow-card",
          "transition-all duration-fast",
          show ? "scale-100 opacity-100" : "scale-95 opacity-0",
        )}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-3 flex items-center justify-between">
          <h2 className="m-0 text-lg font-semibold text-ink">{title}</h2>
          <Button variant="ghost" size="sm" onClick={onClose} aria-label="Close">
            <X size={16} />
          </Button>
        </div>
        {children}
      </div>
    </div>
  );
}
