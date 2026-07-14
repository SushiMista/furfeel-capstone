import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Check, CheckCircle2, Pencil } from "lucide-react";
import { supabase } from "../../lib/supabaseClient.ts";
import {
  addStressLabel,
  buildStressLabelInsert,
  fetchClassificationHistory,
  fetchDog,
  fetchMediaSubmissions,
  fetchStressLabels,
  getMediaSignedUrl,
  reviewMediaSubmission,
  type StressLabelWithVet,
} from "../../lib/queries.ts";
import { useAuth } from "../../lib/useAuth.ts";
import { StressLevelBadge } from "../../components/StressLevelBadge.tsx";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../components/ui/card.tsx";
import { Button } from "../../components/ui/button.tsx";
import { Textarea } from "../../components/ui/input.tsx";
import { Badge } from "../../components/ui/badge.tsx";
import { EmptyState } from "../../components/ui/empty-state.tsx";
import { CardSkeleton } from "../../components/ui/skeleton.tsx";
import { useToast } from "../../components/ui/toast.tsx";
import { cn } from "../../lib/cn.ts";
import type {
  Dog,
  MediaSubmission,
  StressClassification,
  StressLevel,
} from "../../../../../packages/shared/types/index.ts";

const LEVELS: StressLevel[] = ["calm", "mild", "moderate", "high"];

/** Confirm/override stress (docs/05 module 2): the vet reviews the latest rule-v1
 * output and records the clinically correct level. Every save becomes a
 * stress_labels ground-truth row — the dataset for the future Random Forest. */
function ConfirmOverridePanel({
  dogId,
  latest,
  labels,
  onSaved,
}: {
  dogId: string;
  latest: StressClassification | null;
  labels: StressLabelWithVet[];
  onSaved: () => void;
}) {
  const { session } = useAuth();
  const toast = useToast();
  const [selected, setSelected] = useState<StressLevel | null>(null);
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Preselect the model's answer so "confirm" is a single click.
  useEffect(() => {
    if (latest) setSelected((prev) => prev ?? latest.stress_level);
  }, [latest]);

  async function save() {
    const userId = session?.user.id;
    if (!userId || !selected) return;
    setSaving(true);
    setError(null);
    try {
      await addStressLabel(
        supabase,
        buildStressLabelInsert(dogId, userId, selected, latest, note),
      );
      setNote("");
      toast(
        "success",
        latest && latest.stress_level === selected
          ? "Assessment confirmed — thanks, this trains the future model"
          : "Override recorded — thanks, this trains the future model",
      );
      onSaved();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to save the assessment");
    } finally {
      setSaving(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Confirm or override stress</CardTitle>
        <CardDescription>
          Saved assessments become expert-labeled ground truth (model: rule-v1).
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {latest ? (
          <p className="m-0 flex flex-wrap items-center gap-2 text-sm text-ink">
            Latest model output: <StressLevelBadge level={latest.stress_level} />
            <span className="text-xs text-ink-muted">
              score {latest.score ?? "n/a"} · {new Date(latest.created_at).toLocaleString()}
            </span>
          </p>
        ) : (
          <p className="m-0 text-sm text-ink-muted">
            No model classification yet — you can still record a clinical assessment.
          </p>
        )}

        <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="Confirmed stress level">
          {LEVELS.map((level) => {
            const active = selected === level;
            const isModel = latest?.stress_level === level;
            return (
              <button
                key={level}
                type="button"
                role="radio"
                aria-checked={active}
                onClick={() => setSelected(level)}
                className={cn(
                  "inline-flex min-h-10 items-center gap-2 rounded-md border px-4 text-sm font-semibold capitalize",
                  "transition-colors duration-fast",
                  active
                    ? "border-brand bg-brand-soft text-brand-strong"
                    : "border-hairline bg-surface text-ink-muted hover:bg-surface-alt",
                )}
              >
                {active && <Check size={14} />}
                {level}
                {isModel && <span className="text-[10px] font-medium text-ink-muted">(model)</span>}
              </button>
            );
          })}
        </div>

        <Textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Optional clinical note (what you observed, why you overrode…)"
          rows={2}
        />

        {error && (
          <p role="alert" className="m-0 rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
            {error}
          </p>
        )}

        <div>
          <Button onClick={save} disabled={saving || !selected}>
            {saving
              ? "Saving…"
              : latest && selected === latest.stress_level
                ? "Confirm assessment"
                : "Save override"}
          </Button>
        </div>

        <div>
          <h3 className="mb-2 mt-2 text-xs font-semibold uppercase tracking-wide text-ink-muted">
            Past assessments
          </h3>
          {labels.length === 0 ? (
            <EmptyState className="py-6">
              No confirmed assessments yet — each one you save builds the training set 🐾
            </EmptyState>
          ) : (
            <ul className="m-0 flex list-none flex-col gap-2 p-0">
              {labels.map((l) => (
                <li key={l.id} className="flex flex-wrap items-center gap-2 rounded-md bg-surface-alt px-3 py-2">
                  <StressLevelBadge level={l.confirmed_level} />
                  {l.agreed_with_model !== null && (
                    <Badge variant={l.agreed_with_model ? "neutral" : "default"}>
                      {l.agreed_with_model ? "confirmed model" : "override"}
                    </Badge>
                  )}
                  <span className="text-xs text-ink-muted">
                    {l.vet?.name ?? "Clinic staff"} · {new Date(l.created_at).toLocaleString()}
                  </span>
                  {l.note && <span className="w-full text-sm text-ink">{l.note}</span>}
                </li>
              ))}
            </ul>
          )}
        </div>
      </CardContent>
    </Card>
  );
}

/** One owner-submitted media item: signed-URL preview (private bucket), owner note,
 * review status, and a mark-reviewed + annotate flow. */
function MediaItem({ media, onReviewed }: { media: MediaSubmission; onReviewed: (m: MediaSubmission) => void }) {
  const { session } = useAuth();
  const toast = useToast();
  const [url, setUrl] = useState<string | null>(null);
  const [urlError, setUrlError] = useState(false);
  const [annotating, setAnnotating] = useState(false);
  const [reviewNote, setReviewNote] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    getMediaSignedUrl(supabase, media.storage_path)
      .then((signed) => {
        if (!cancelled) setUrl(signed);
      })
      .catch(() => {
        if (!cancelled) setUrlError(true);
      });
    return () => {
      cancelled = true;
    };
  }, [media.storage_path]);

  async function markReviewed() {
    const userId = session?.user.id;
    if (!userId) return;
    setSaving(true);
    try {
      const updated = await reviewMediaSubmission(
        supabase,
        media.id,
        userId,
        reviewNote.trim() === "" ? null : reviewNote.trim(),
      );
      toast("success", "Marked as reviewed");
      setAnnotating(false);
      onReviewed(updated);
    } catch (err) {
      toast("error", err instanceof Error ? err.message : "Failed to save the review");
    } finally {
      setSaving(false);
    }
  }

  const reviewed = media.reviewed_at !== null;

  return (
    <li className="flex flex-col gap-3 rounded-md border border-hairline p-4">
      <div className="flex items-center justify-between gap-3">
        <span className="text-xs text-ink-muted">
          Submitted {new Date(media.created_at).toLocaleString()}
        </span>
        {reviewed ? (
          <Badge variant="neutral">
            <CheckCircle2 size={12} /> reviewed
          </Badge>
        ) : (
          <Badge>awaiting review</Badge>
        )}
      </div>

      {url ? (
        media.media_type === "video" ? (
          // eslint-disable-next-line jsx-a11y/media-has-caption
          <video src={url} controls className="max-h-72 w-full rounded-md bg-ink object-contain" />
        ) : (
          <img
            src={url}
            alt={media.note ?? "Owner-submitted observation"}
            className="max-h-72 w-full rounded-md bg-surface-alt object-contain"
          />
        )
      ) : urlError ? (
        <p className="m-0 rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
          Couldn&apos;t load this file from storage.
        </p>
      ) : (
        <div className="h-40 animate-pulse rounded-md bg-surface-alt" />
      )}

      {media.note && (
        <p className="m-0 text-sm text-ink">
          <span className="font-semibold">Owner&apos;s note:</span> {media.note}
        </p>
      )}
      {media.review_note && (
        <p className="m-0 text-sm text-ink">
          <span className="font-semibold">Clinic annotation:</span> {media.review_note}
        </p>
      )}

      {!reviewed &&
        (annotating ? (
          <div className="flex flex-col gap-2">
            <Textarea
              value={reviewNote}
              onChange={(e) => setReviewNote(e.target.value)}
              placeholder="Optional annotation for the owner and the record…"
              rows={2}
            />
            <div className="flex gap-2">
              <Button size="sm" onClick={markReviewed} disabled={saving}>
                {saving ? "Saving…" : "Mark reviewed"}
              </Button>
              <Button size="sm" variant="ghost" onClick={() => setAnnotating(false)}>
                Cancel
              </Button>
            </div>
          </div>
        ) : (
          <div>
            <Button size="sm" variant="secondary" onClick={() => setAnnotating(true)}>
              <Pencil size={12} /> Review &amp; annotate
            </Button>
          </div>
        ))}
    </li>
  );
}

/** Vet Review (docs/05 module 2): biometrics context + owner-submitted media review
 * + the confirm/override control that writes ground-truth stress_labels. */
export function VetReview() {
  const { dogId } = useParams<{ dogId: string }>();
  const [dog, setDog] = useState<Dog | null>(null);
  const [latest, setLatest] = useState<StressClassification | null>(null);
  const [labels, setLabels] = useState<StressLabelWithVet[]>([]);
  const [media, setMedia] = useState<MediaSubmission[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!dogId) return;
    try {
      const [dogRow, classifications, labelRows, mediaRows] = await Promise.all([
        fetchDog(supabase, dogId),
        fetchClassificationHistory(supabase, dogId, 1),
        fetchStressLabels(supabase, dogId),
        fetchMediaSubmissions(supabase, dogId),
      ]);
      setDog(dogRow);
      setLatest(classifications[classifications.length - 1] ?? null);
      setLabels(labelRows);
      setMedia(mediaRows);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load vet review");
    } finally {
      setLoading(false);
    }
  }, [dogId]);

  useEffect(() => {
    load();
  }, [load]);

  if (loading)
    return (
      <div className="flex flex-col gap-4">
        <CardSkeleton lines={3} />
        <CardSkeleton lines={3} />
      </div>
    );
  if (error)
    return (
      <p role="alert" className="rounded-sm bg-high-soft px-3 py-2 text-sm text-high-fg">
        {error}
      </p>
    );
  if (!dog)
    return (
      <EmptyState>
        We couldn&apos;t find that dog (or they&apos;re not visible to your account).
      </EmptyState>
    );

  return (
    <div className="flex flex-col gap-5">
      <Link
        to={`/dogs/${dog.id}`}
        className="inline-flex items-center gap-1 text-sm font-medium text-ink-muted hover:text-brand-strong"
      >
        <ArrowLeft size={14} /> {dog.name}
      </Link>

      <h1 className="m-0 flex items-center gap-3 text-2xl font-bold text-ink">
        Vet review — {dog.name}
        {latest && <StressLevelBadge level={latest.stress_level} />}
      </h1>

      <ConfirmOverridePanel dogId={dog.id} latest={latest} labels={labels} onSaved={load} />

      <Card>
        <CardHeader>
          <CardTitle>Owner-submitted media</CardTitle>
          <CardDescription>
            Supplementary context from the owner — not used by the stress classifier.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {media.length === 0 ? (
            <EmptyState>
              No submissions yet — owners can share photos and short videos from the app 🐾
            </EmptyState>
          ) : (
            <ul className="m-0 flex list-none flex-col gap-4 p-0">
              {media.map((m) => (
                <MediaItem
                  key={m.id}
                  media={m}
                  onReviewed={(updated) =>
                    setMedia((prev) => prev.map((x) => (x.id === updated.id ? updated : x)))
                  }
                />
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
