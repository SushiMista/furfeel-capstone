import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { Send } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { friendlyError } from "../../lib/errors.ts";
import { useAuth } from "../../lib/useAuth.ts";
import {
  fetchDogMessages,
  fetchDogMessageThreads,
  fetchDogs,
  getMediaSignedUrl,
  markDogMessagesRead,
  sendDogMessage,
  type DogMessage,
  type DogMessageThread,
} from "../../lib/queries.ts";
import { Card, CardContent } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Textarea } from "../../components/ui/input.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { useToast } from "../../components/ui/toast.tsx";
import { cn } from "../../lib/cn.ts";
import { formatPhilippineTime } from "../../lib/time.ts";
import type { Dog } from "../../../../../packages/shared/types/index.ts";

const ALERT_TITLES: Record<string, string> = {
  high_stress: "High stress alert",
  moderate_stress: "Moderate stress alert",
  device_offline: "Device stopped sending data",
  low_battery: "Low battery",
};

export function threadPreview(thread: DogMessageThread): string {
  if (thread.last_body) return thread.last_body;
  if (thread.last_has_media) return "Photo or video";
  return "Shared an alert";
}

function MessageMedia({ message }: { message: DogMessage }) {
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let active = true;
    getMediaSignedUrl(supabase, message.media_path!)
      .then((signed) => active && setUrl(signed))
      .catch(() => active && setFailed(true));
    return () => {
      active = false;
    };
  }, [message.media_path]);

  if (failed) return <p className="text-xs text-ink-muted">This file couldn't be loaded.</p>;
  if (!url) return <div className="h-32 w-48 animate-pulse rounded-lg bg-surface-alt" />;
  return message.media_type === "video" ? (
    <video src={url} controls className="max-h-64 max-w-full rounded-lg" />
  ) : (
    <img src={url} alt="Shared by the owner" className="max-h-64 max-w-full rounded-lg" />
  );
}

function MessageBubble({ message, mine }: { message: DogMessage; mine: boolean }) {
  const reading = message.reading;
  return (
    <li className={cn("flex", mine ? "justify-end" : "justify-start")}>
      <div
        className={cn(
          "flex max-w-[75%] flex-col gap-1.5 rounded-xl px-3 py-2 text-sm",
          mine ? "bg-brand-soft text-ink" : "bg-surface-alt text-ink",
        )}
      >
        {!mine && (
          <span className="text-xs font-semibold text-ink-muted">
            {message.author?.name ?? "Owner"}
          </span>
        )}
        {message.alert && (
          <div className="rounded-lg border border-hairline bg-surface px-2.5 py-1.5">
            <p className="m-0 font-semibold">
              {ALERT_TITLES[message.alert.type] ?? "Alert"}
            </p>
            {reading && (
              <p className="m-0 text-xs text-ink-muted">
                {reading.heart_rate_bpm != null && `${reading.heart_rate_bpm} bpm · `}
                {reading.ambient_temperature_c != null && `${reading.ambient_temperature_c}°C · `}
                {formatPhilippineTime(reading.captured_at)}
              </p>
            )}
          </div>
        )}
        {message.media_path && <MessageMedia message={message} />}
        {message.body && <p className="m-0 whitespace-pre-wrap">{message.body}</p>}
        <span className="text-xs text-ink-muted">
          {formatPhilippineTime(message.created_at)}
          {message.edited_at ? " · edited" : ""}
        </span>
      </div>
    </li>
  );
}

export function Conversation({
  dog,
  onRead,
  embedded = false,
}: {
  dog: Dog;
  onRead?: () => void;
  /** On the dog's own page, where the name and link would repeat. */
  embedded?: boolean;
}) {
  const { session } = useAuth();
  const toast = useToast();
  const userId = session?.user.id;
  const [messages, setMessages] = useState<DogMessage[]>([]);
  const [loading, setLoading] = useState(true);
  const [draft, setDraft] = useState("");
  const [sending, setSending] = useState(false);
  const endRef = useRef<HTMLLIElement>(null);

  const load = useCallback(async () => {
    try {
      setMessages(await fetchDogMessages(supabase, dog.id));
      if (userId) {
        await markDogMessagesRead(supabase, dog.id, userId);
        onRead?.();
      }
    } catch (err) {
      toast("error", friendlyError(err, "load these messages"));
    } finally {
      setLoading(false);
    }
  }, [dog.id, userId, onRead, toast]);

  useEffect(() => {
    setLoading(true);
    load();
    const channel = supabase
      .channel(`dog_messages_${dog.id}`)
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "dog_messages", filter: `dog_id=eq.${dog.id}` },
        () => load(),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [dog.id, load]);

  useEffect(() => {
    endRef.current?.scrollIntoView?.();
  }, [messages]);

  async function send(e: FormEvent) {
    e.preventDefault();
    if (!userId || !draft.trim()) return;
    setSending(true);
    try {
      await sendDogMessage(supabase, dog.id, userId, draft);
      setDraft("");
      await load();
    } catch (err) {
      toast("error", friendlyError(err, "send your reply"));
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="flex h-full min-h-0 flex-col">
      {!embedded && (
        <div className="flex items-center justify-between border-b border-hairline px-4 py-3">
          <h2 className="m-0 text-base font-semibold text-ink">{dog.name}</h2>
          <Link to={`/dogs/${dog.id}`} className="text-sm text-brand">
            View patient
          </Link>
        </div>
      )}
      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-3">
        {loading ? (
          <CardSkeleton />
        ) : messages.length === 0 ? (
          <EmptyState>No messages yet.</EmptyState>
        ) : (
          <ul className="m-0 flex list-none flex-col gap-3 p-0">
            {messages.map((m) => (
              <MessageBubble key={m.id} message={m} mine={m.author_user_id === userId} />
            ))}
            <li ref={endRef} />
          </ul>
        )}
      </div>
      <form onSubmit={send} className="flex items-end gap-2 border-t border-hairline p-3">
        <Textarea
          aria-label={`Message about ${dog.name}`}
          placeholder="Write a reply"
          rows={2}
          maxLength={4000}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
        />
        <Button type="submit" disabled={sending || !draft.trim()} aria-label="Send">
          <Send size={16} aria-hidden="true" />
        </Button>
      </form>
    </div>
  );
}

/** Vet inbox (ADR-026): every dog's conversation, unread first in view. Owner
 * media and messages are supplementary and never reach the classifier. */
export function Messages() {
  const [params, setParams] = useSearchParams();
  const toast = useToast();
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [threads, setThreads] = useState<DogMessageThread[]>([]);
  const [loading, setLoading] = useState(true);

  const refreshThreads = useCallback(() => {
    fetchDogMessageThreads(supabase)
      .then(setThreads)
      .catch((err) => toast("error", friendlyError(err, "load messages")));
  }, [toast]);

  useEffect(() => {
    Promise.all([fetchDogs(supabase), fetchDogMessageThreads(supabase)])
      .then(([dogRows, threadRows]) => {
        setDogs(dogRows);
        setThreads(threadRows);
      })
      .catch((err) => toast("error", friendlyError(err, "load messages")))
      .finally(() => setLoading(false));
  }, [toast]);

  useEffect(() => {
    const channel = supabase
      .channel("dog_messages_inbox")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "dog_messages" },
        () => refreshThreads(),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [refreshThreads]);

  const threadByDog = useMemo(
    () => new Map(threads.map((t) => [t.dog_id, t])),
    [threads],
  );
  const rows = useMemo(
    () =>
      [...dogs].sort((a, b) => {
        const at = threadByDog.get(a.id)?.last_at ?? "";
        const bt = threadByDog.get(b.id)?.last_at ?? "";
        return bt.localeCompare(at) || a.name.localeCompare(b.name);
      }),
    [dogs, threadByDog],
  );
  const selected = dogs.find((d) => d.id === params.get("dog")) ?? null;

  if (loading) return <CardSkeleton />;

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="m-0 text-2xl font-bold text-ink">Messages</h1>
        <p className="m-0 text-sm text-ink-muted">
          Conversations with owners. Supplementary context, not used by the stress classifier.
        </p>
      </div>
      <Card>
        <CardContent className="grid h-[70vh] min-h-96 grid-cols-1 gap-0 p-0 md:grid-cols-[280px_1fr]">
          <ul className="m-0 min-h-0 list-none overflow-y-auto border-b border-hairline p-0 md:border-b-0 md:border-r">
            {rows.map((dog) => {
              const thread = threadByDog.get(dog.id);
              const unread = Number(thread?.unread_count ?? 0);
              return (
                <li key={dog.id}>
                  <button
                    type="button"
                    onClick={() => setParams({ dog: dog.id })}
                    aria-current={selected?.id === dog.id ? "true" : undefined}
                    className={cn(
                      "flex w-full items-center gap-2 border-b border-hairline px-4 py-3 text-left",
                      selected?.id === dog.id && "bg-brand-soft",
                    )}
                  >
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-semibold text-ink">{dog.name}</span>
                      <span
                        className={cn(
                          "block truncate text-xs text-ink-muted",
                          unread > 0 && "font-semibold text-ink",
                        )}
                      >
                        {thread ? threadPreview(thread) : "No messages yet"}
                      </span>
                    </span>
                    {unread > 0 && (
                      <span
                        aria-label={`${unread} unread`}
                        className="rounded-full bg-brand px-2 py-0.5 text-xs font-semibold text-white"
                      >
                        {unread}
                      </span>
                    )}
                  </button>
                </li>
              );
            })}
          </ul>
          {selected ? (
            <Conversation key={selected.id} dog={selected} onRead={refreshThreads} />
          ) : (
            <div className="flex items-center justify-center p-6">
              <EmptyState>Choose a dog to read or reply.</EmptyState>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
