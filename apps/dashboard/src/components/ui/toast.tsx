// ADDED: lightweight toast system (success/error feedback on writes) — docs/19 motion:
// gentle slide+fade, auto-dismiss, reduced-motion respected via CSS.
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { CheckCircle2, XCircle } from "lucide-react";
import { cn } from "../../lib/cn.ts";

interface Toast {
  id: number;
  kind: "success" | "error" | "info";
  message: ReactNode;
}

const ToastContext = createContext<(kind: Toast["kind"], message: ReactNode) => void>(() => {});

export function useToast() {
  return useContext(ToastContext);
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const nextId = useRef(1);

  const push = useCallback((kind: Toast["kind"], message: ReactNode) => {
    const id = nextId.current++;
    setToasts((prev) => [...prev, { id, kind, message }]);
    setTimeout(() => setToasts((prev) => prev.filter((t) => t.id !== id)), 6000); // 6s duration for richer notifications
  }, []);

  const value = useMemo(() => push, [push]);

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div
        className="pointer-events-none fixed bottom-4 right-4 z-50 flex flex-col gap-2"
        aria-live="polite"
      >
        {toasts.map((t) => (
          <div
            key={t.id}
            className={cn(
              "pointer-events-auto flex items-center gap-2 rounded-md border px-4 py-3 text-sm shadow-card max-w-sm w-auto",
              "animate-[toast-in_150ms_ease-out]",
              t.kind === "success" && "border-calm/30 bg-calm-soft text-calm-fg",
              t.kind === "error" && "border-high/30 bg-high-soft text-high-fg",
              t.kind === "info" && "border-hairline bg-surface text-ink",
            )}
            role="status"
          >
            {t.kind === "success" && <CheckCircle2 size={16} className="flex-shrink-0" />}
            {t.kind === "error" && <XCircle size={16} className="flex-shrink-0" />}
            {t.message}
          </div>
        ))}
      </div>
      <style>{`@keyframes toast-in { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: none; } }`}</style>
    </ToastContext.Provider>
  );
}
