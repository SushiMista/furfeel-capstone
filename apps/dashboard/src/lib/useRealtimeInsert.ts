import { useEffect, useRef } from "react";
import { supabase } from "./supabaseClient.ts";

/** Subscribes to INSERT events on `table` for the lifetime of the calling component.
 * No dog_id filter is applied -- RLS scopes which rows actually get delivered
 * (docs/10 Realtime), so this stays a single subscription per table regardless of
 * how many dogs are on the board. */
export function useRealtimeInsert<T>(table: string, onInsert: (row: T) => void): void {
  const handlerRef = useRef(onInsert);
  handlerRef.current = onInsert;

  useEffect(() => {
    const channel = supabase
      .channel(`${table}-inserts-${Math.random().toString(36).slice(2)}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table },
        (payload) => handlerRef.current(payload.new as T),
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [table]);
}
