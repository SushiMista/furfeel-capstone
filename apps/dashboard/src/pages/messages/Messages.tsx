import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { Search, Send } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import { friendlyError } from "../../lib/errors.ts";
import { useAuth } from "../../lib/useAuth.ts";
import {
  fetchDogMessages,
  fetchDogMessageThreads,
  fetchDogs,
  fetchMonitoringBoard,
  fetchMonitoringBoardRowForDog,
  getMediaSignedUrl,
  markDogMessagesRead,
  sendDogMessage,
  type DogMessage,
  type DogMessageThread,
  type MonitoringBoardRow,
} from "../../lib/queries.ts";
import { DogPhoto } from "../../components/DogPhoto.tsx";
import { StressLevelBadge } from "../../components/StressLevelBadge.tsx";
import { Card, CardContent } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Input, Textarea } from "../../components/ui/input.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { useToast } from "../../components/ui/toast.tsx";
import { cn } from "../../lib/cn.ts";
import { formatPhilippineTime, timeAgo } from "../../lib/time.ts";
import type { Dog, StressLevel } from "../../../../../packages/shared/types/index.ts";

const LEVEL_DOT: Record<StressLevel, string> = {
  calm: "bg-calm-fg",
  mild: "bg-mild-fg",
  moderate: "bg-moderate-fg",
  high: "bg-high-fg",
};
const LEVEL_RANK: Record<StressLevel, number> = { calm: 1, mild: 2, moderate: 3, high: 4 };

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

export function Conversation({ dog, onRead }: { dog: Dog; onRead?: () => void }) {
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

/** The dog's status beside its chat, refreshed as new classifications arrive. */
function DogStatusPanel({ dog }: { dog: Dog }) {
  const [row, setRow] = useState<MonitoringBoardRow | null>(null);

  useEffect(() => {
    const refresh = () => {
      fetchMonitoringBoardRowForDog(supabase, dog).then(setRow).catch(() => {});
    };
    refresh();
    const channel = supabase
      .channel(`dog_status_${dog.id}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "stress_classifications",
          filter: `dog_id=eq.${dog.id}`,
        },
        refresh,
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [dog]);

  const reading = row?.latestReading;
  return (
    <aside className="flex flex-col gap-2 border-t border-hairline p-4 md:border-l md:border-t-0">
      <h2 className="m-0 truncate text-base font-semibold text-ink">{dog.name}</h2>
      {row?.device?.status === "offline" ? (
        <span className="w-fit rounded-full bg-surface-alt px-2.5 py-0.5 text-xs font-semibold text-ink-muted">
          Offline
        </span>
      ) : row?.latestClassification ? (
        <span className="w-fit">
          <StressLevelBadge level={row.latestClassification.stress_level} />
        </span>
      ) : (
        <p className="m-0 text-xs text-ink-muted">No stress reading yet</p>
      )}
      {reading && (
        <dl className="m-0 grid grid-cols-[1fr_auto] gap-x-2 gap-y-1 text-xs">
          <dt className="text-ink-muted">Heart</dt>
          <dd className="m-0 text-ink">{reading.heart_rate_bpm ?? "—"} bpm</dd>
          <dt className="text-ink-muted">Breathing</dt>
          <dd className="m-0 text-ink">{reading.respiratory_rate_bpm ?? "—"} br/min</dd>
          <dt className="text-ink-muted">Open alerts</dt>
          <dd className="m-0 text-ink">{row?.openAlertCount ?? 0}</dd>
          <dt className="text-ink-muted">Updated</dt>
          <dd className="m-0 text-ink">{timeAgo(reading.captured_at)}</dd>
        </dl>
      )}
      <Link to={`/dogs/${dog.id}`} className="mt-auto text-sm font-semibold text-brand">
        Open dog
      </Link>
    </aside>
  );
}

/** Vet inbox (ADR-026): every dog's conversation, unread first in view. Owner
 * media and messages are supplementary and never reach the classifier. */
export function Messages() {
  const [params, setParams] = useSearchParams();
  const toast = useToast();
  const [dogs, setDogs] = useState<Dog[]>([]);
  const [threads, setThreads] = useState<DogMessageThread[]>([]);
  const [levels, setLevels] = useState<Map<string, StressLevel>>(new Map());
  const [unreadOnly, setUnreadOnly] = useState(false);
  const [search, setSearch] = useState("");
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
    fetchMonitoringBoard(supabase)
      .then((board) =>
        setLevels(
          new Map(
            board.flatMap(({ dog, device, latestClassification }) =>
              latestClassification && device?.status !== "offline"
                ? [[dog.id, latestClassification.stress_level]]
                : [],
            ),
          ),
        ),
      )
      .catch(() => {});
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
  const unreadOf = useCallback(
    (dogId: string) => Number(threadByDog.get(dogId)?.unread_count ?? 0),
    [threadByDog],
  );
  // Unread first, then the most stressed dogs, then the latest conversation.
  const rows = useMemo(() => {
    const rank = (id: string) => LEVEL_RANK[levels.get(id) ?? "calm"];
    const query = search.trim().toLowerCase();
    return dogs
      .filter((d) => !unreadOnly || unreadOf(d.id) > 0)
      .filter((d) => [d.name, d.breed].some((text) => text?.toLowerCase().includes(query)))
      .sort((a, b) => {
        const at = threadByDog.get(a.id)?.last_at ?? "";
        const bt = threadByDog.get(b.id)?.last_at ?? "";
        return (
          Number(unreadOf(b.id) > 0) - Number(unreadOf(a.id) > 0) ||
          rank(b.id) - rank(a.id) ||
          bt.localeCompare(at) ||
          a.name.localeCompare(b.name)
        );
      });
  }, [dogs, levels, search, threadByDog, unreadOf, unreadOnly]);
  const unreadTotal = dogs.filter((d) => unreadOf(d.id) > 0).length;
  const selected = dogs.find((d) => d.id === params.get("dog")) ?? null;

  if (loading) return <CardSkeleton />;

  return (
    <div className="flex flex-col gap-4">
      <h1 className="m-0 text-2xl font-bold text-ink">Messages</h1>
      <Card>
        <CardContent
          className={cn(
            "grid h-[calc(100vh-6.25rem)] min-h-96 grid-cols-1 gap-0 p-0",
            selected ? "md:grid-cols-[260px_1fr_200px]" : "md:grid-cols-[260px_1fr]",
          )}
        >
          <div className="flex min-h-0 flex-col border-b border-hairline md:border-b-0 md:border-r">
            <div className="relative border-b border-hairline p-2">
              <Search
                size={14}
                aria-hidden="true"
                className="absolute left-4.5 top-1/2 -translate-y-1/2 text-ink-muted"
              />
              <Input
                type="search"
                aria-label="Search patients"
                placeholder="Search patients"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="h-8 pl-8 text-xs"
              />
            </div>
            <div className="flex gap-1.5 border-b border-hairline p-2">
              {[
                { label: "All", active: !unreadOnly, value: false },
                { label: `Unread ${unreadTotal}`, active: unreadOnly, value: true },
              ].map(({ label, active, value }) => (
                <button
                  key={label}
                  type="button"
                  aria-pressed={active}
                  onClick={() => setUnreadOnly(value)}
                  className={cn(
                    "cursor-pointer rounded-full border px-3 py-1 text-xs font-semibold",
                    active
                      ? "border-brand bg-brand text-white"
                      : "border-hairline bg-surface text-ink-muted hover:bg-surface-alt",
                  )}
                >
                  {label}
                </button>
              ))}
            </div>
            <ul className="m-0 min-h-0 flex-1 list-none overflow-y-auto p-0">
              {rows.length === 0 && (
                <li className="p-4 text-sm text-ink-muted">No patients match your search.</li>
              )}
            {rows.map((dog) => {
              const thread = threadByDog.get(dog.id);
              const unread = unreadOf(dog.id);
              const level = levels.get(dog.id);
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
                    <DogPhoto dog={dog} className="h-8 w-8 rounded-lg" />
                    <span className="min-w-0 flex-1">
                      <span className="flex items-center gap-1.5 text-sm font-semibold text-ink">
                        <span
                          aria-hidden="true"
                          className={cn("h-2 w-2 shrink-0 rounded-full", level ? LEVEL_DOT[level] : "bg-hairline")}
                        />
                        <span className="truncate">{dog.name}</span>
                        {level && <span className="sr-only">, {level}</span>}
                      </span>
                      <span
                        className={cn(
                          "block truncate text-xs text-ink-muted",
                          unread > 0 && "font-semibold text-ink",
                        )}
                      >
                        {thread ? `${timeAgo(thread.last_at)} · ${threadPreview(thread)}` : "No messages yet"}
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
          </div>
          {selected ? (
            <>
              <Conversation key={selected.id} dog={selected} onRead={refreshThreads} />
              <DogStatusPanel key={`status-${selected.id}`} dog={selected} />
            </>
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
