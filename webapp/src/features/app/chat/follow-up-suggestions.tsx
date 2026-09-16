'use client';

/**
 * FollowUpSuggestions — small question chips offered after the latest
 * assistant reply.
 *
 * Suggestions are generated contextually through the Assist runtime
 * (/api/suggest — a short, one-shot call). When the network is unavailable
 * or Strict Offline blocks the call, honest local template questions are
 * used instead and quietly labelled. Clicking a chip drops it into the
 * composer for review — nothing is auto-sent.
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import { ArrowRight, RefreshCw, Sparkles, X } from 'lucide-react';
import { cn } from '@/lib/utils';

/** Template fallbacks — conversation-agnostic but genuinely useful. */
const LOCAL_SUGGESTIONS = [
  'Summarize this in two sentences',
  'What are the main trade-offs?',
  'Show me a concrete example',
];

/**
 * Module-level memo: messageId → resolved suggestions. Navigating between
 * views remounts the chat (and its chips) — without this cache every
 * remount would fire a fresh /api/suggest call for the same reply.
 */
const suggestionCache = new Map<string, { items: string[]; source: 'network' | 'local' }>();

interface SuggestionsState {
  messageId: string;
  items: string[];
  source: 'network' | 'local';
}

/**
 * Fetches follow-up suggestions for an exchange. Network path goes through
 * the gateway (audited, Strict-Offline aware); any failure falls back to
 * the local template list so the affordance never dies. Results are cached
 * per assistant message id.
 */
export async function fetchSuggestions(
  messageId: string,
  user: string,
  assistant: string
): Promise<{ items: string[]; source: 'network' | 'local' }> {
  const cached = suggestionCache.get(messageId);
  if (cached) return cached;

  let result: { items: string[]; source: 'network' | 'local' };
  try {
    const { gateway } = await import('@/lib/core/net/network-gateway');
    const res = await gateway.request('assist-suggest', '/api/suggest', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user: user.slice(0, 1500), assistant: assistant.slice(0, 2500) }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const json = (await res.json()) as { suggestions?: string[] };
    if (json.suggestions?.length) {
      result = { items: json.suggestions.slice(0, 3), source: 'network' };
    } else {
      throw new Error('empty');
    }
  } catch {
    // Transient failures are NOT cached — the next mount retries the
    // network before falling back again.
    return { items: LOCAL_SUGGESTIONS, source: 'local' };
  }
  suggestionCache.set(messageId, result);
  return result;
}

/** Drops the cached suggestions for a message so the next fetch retries
 *  (used by the regenerate affordance). */
export function invalidateSuggestions(messageId: string): void {
  suggestionCache.delete(messageId);
}

export function FollowUpSuggestions({
  messageId,
  userText,
  assistantText,
  onPick,
}: {
  /** The assistant message these suggestions belong to. */
  messageId: string;
  /** Last user message (context for the generator). */
  userText: string;
  /** The assistant reply being followed up on. */
  assistantText: string;
  onPick: (text: string) => void;
}) {
  const [state, setState] = useState<SuggestionsState | null>(null);
  const [dismissed, setDismissed] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const requestedFor = useRef<string | null>(null);

  const load = useCallback(async () => {
    if (requestedFor.current === messageId) return;
    requestedFor.current = messageId;
    const { items, source } = await fetchSuggestions(messageId, userText, assistantText);
    setState({ messageId, items, source });
  }, [messageId, userText, assistantText]);

  useEffect(() => {
    void load();
  }, [load]);

  /** Regenerate — drop the memo for this reply and fetch fresh questions. */
  const regenerate = useCallback(async () => {
    invalidateSuggestions(messageId);
    requestedFor.current = null;
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }, [messageId, load]);

  if (dismissed || !state || state.messageId !== messageId) return null;

  return (
    <div
      className="mx-auto mb-1.5 w-full max-w-3xl px-3 md:px-4 animate-rise-in"
      data-testid="follow-up-suggestions"
    >
      <div className="flex flex-wrap items-center gap-1.5">
        <span className="flex items-center gap-1 pr-0.5 text-[10px] font-medium uppercase tracking-wider text-muted-foreground/70">
          <Sparkles className="h-3 w-3 text-brand-strong" aria-hidden />
          <span className="sr-only">Suggested follow-ups</span>
          {state.source === 'local' && (
            <span className="normal-case" title="Generated offline from templates">
              offline
            </span>
          )}
        </span>
        {state.items.map((text) => (
          <button
            key={text}
            type="button"
            onClick={() => onPick(text)}
            className="group/sug inline-flex max-w-full items-center gap-1.5 rounded-full border border-border bg-card px-3 py-1.5 text-[12px] text-muted-foreground transition-all hover:-translate-y-px hover:border-brand-strong hover:text-foreground hover:shadow-sm"
          >
            <span className="truncate">{text}</span>
            <ArrowRight
              className="h-3 w-3 shrink-0 opacity-0 transition-opacity group-hover/sug:opacity-100"
              aria-hidden
            />
          </button>
        ))}
        <button
          type="button"
          onClick={() => void regenerate()}
          className="rounded-full p-1.5 text-muted-foreground/50 transition-colors hover:bg-muted hover:text-foreground"
          aria-label="Regenerate follow-up suggestions"
          title="Regenerate suggestions"
          disabled={refreshing}
        >
          <RefreshCw
            className={cn('h-3 w-3', refreshing && 'animate-spin')}
            aria-hidden
          />
        </button>
        <button
          type="button"
          onClick={() => setDismissed(true)}
          className="rounded-full p-1.5 text-muted-foreground/50 transition-colors hover:bg-muted hover:text-foreground"
          aria-label="Dismiss follow-up suggestions"
          title="Dismiss"
        >
          <X className="h-3 w-3" />
        </button>
      </div>
    </div>
  );
}

/** Shimmer placeholder shown while suggestions generate. */
export function FollowUpSkeleton() {
  return (
    <div className="mx-auto mb-1.5 w-full max-w-3xl px-3 md:px-4" aria-hidden>
      <div className="flex flex-wrap items-center gap-1.5">
        {Array.from({ length: 3 }).map((_, i) => (
          <span
            key={i}
            className={cn(
              'h-7 animate-pulse rounded-full bg-muted',
              i === 0 ? 'w-36' : i === 1 ? 'w-44' : 'w-32'
            )}
            style={{ animationDelay: `${i * 120}ms` }}
          />
        ))}
      </div>
    </div>
  );
}
