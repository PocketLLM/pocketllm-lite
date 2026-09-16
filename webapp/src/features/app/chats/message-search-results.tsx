'use client';

/**
 * MessageSearchResults — message-level search results for the History view.
 *
 * While the chat-level list shows which conversations match, this section
 * shows the individual matching messages: role, snippet with the query
 * highlighted, per-message match count, chat title and a relative time.
 * Clicking a result opens the chat and scrolls to (and flashes) the exact
 * message via the deep-link hand-off.
 */
import { useMemo, useState } from 'react';
import { ArrowRight, Bot, ChevronDown, MessageSquareText, User } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { deepLink } from '@/lib/core/deep-link';
import { router } from '@/lib/core/router';
import type { Chat, Message } from '@/lib/types/domain';
import { cn, formatRelativeTime } from '@/lib/utils';
import { EmptyState } from '@/features/app/shared/ui';

/** A single search hit with pre-computed snippet parts. */
export interface MessageHit {
  message: Message;
  chat: Chat;
  /** Count of query occurrences inside this message. */
  matchCount: number;
  /** Snippet split around occurrences: [before, query, between, query, …]. */
  parts: Array<{ text: string; hit: boolean }>;
}

const SNIPPET_RADIUS = 60;
const PAGE_SIZE = 12;

/** Case-insensitive occurrence positions of `needle` inside `haystack`. */
function findMatches(haystack: string, needle: string): number[] {
  const positions: number[] = [];
  const lower = haystack.toLowerCase();
  const q = needle.toLowerCase();
  let i = lower.indexOf(q);
  while (i !== -1 && positions.length < 50) {
    positions.push(i);
    i = lower.indexOf(q, i + q.length);
  }
  return positions;
}

/** Builds a snippet around the first occurrence, marking every hit inside it. */
function buildSnippet(content: string, positions: number[], queryLength: number) {
  const first = positions[0];
  const start = Math.max(0, first - SNIPPET_RADIUS);
  const end = Math.min(
    content.length,
    first + queryLength + SNIPPET_RADIUS * 2
  );
  const prefix = start > 0 ? '…' : '';
  const suffix = end < content.length ? '…' : '';
  const text = prefix + content.slice(start, end) + suffix;

  // Translate absolute positions to snippet-relative ones.
  const rel = positions
    .map((p) => p - start + prefix.length)
    .filter((p) => p >= 0 && p + queryLength <= text.length);

  const parts: Array<{ text: string; hit: boolean }> = [];
  let cursor = 0;
  for (const p of rel) {
    if (p < cursor) continue; // overlapping (already consumed)
    if (p > cursor) parts.push({ text: text.slice(cursor, p), hit: false });
    parts.push({ text: text.slice(p, p + queryLength), hit: true });
    cursor = p + queryLength;
  }
  if (cursor < text.length) parts.push({ text: text.slice(cursor), hit: false });
  return parts;
}

/**
 * Computes message hits for a query. Messages are searched newest-first,
 * capped at 200 hits to keep the render cheap on large histories.
 */
export function searchMessages(
  query: string,
  messagesByChat: Map<string, Message[]>,
  chatsById: Map<string, Chat>
): MessageHit[] {
  const q = query.trim();
  if (q.length === 0) return [];
  const hits: MessageHit[] = [];
  const sortedChats = [...chatsById.values()].sort(
    (a, b) => b.lastMessageAt - a.lastMessageAt
  );
  for (const chat of sortedChats) {
    const msgs = messagesByChat.get(chat.id);
    if (!msgs) continue;
    // Newest messages first within a chat.
    const ordered = [...msgs].sort((a, b) => b.createdAt - a.createdAt);
    for (const m of ordered) {
      if (!m.content) continue;
      const positions = findMatches(m.content, q);
      if (positions.length === 0) continue;
      hits.push({
        message: m,
        chat,
        matchCount: positions.length,
        parts: buildSnippet(m.content, positions, q.length),
      });
      if (hits.length >= 200) return hits;
    }
  }
  return hits;
}

export function MessageSearchResults({
  query,
  hits,
}: {
  query: string;
  hits: MessageHit[];
}) {
  const [expanded, setExpanded] = useState(false);

  const visibleHits = useMemo(
    () => (expanded ? hits : hits.slice(0, PAGE_SIZE)),
    [hits, expanded]
  );

  const openAt = (hit: MessageHit) => {
    // Deposit the message deep link (with the query for jump-context
    // highlighting), then navigate — ChatView consumes it on mount and
    // scrolls + flashes the exact message.
    deepLink.set({
      kind: 'message',
      id: hit.message.id,
      chatId: hit.chat.id,
      query: query.trim(),
    });
    router.navigate(`/app/chat/${hit.chat.id}`);
  };

  if (query.trim().length === 0) return null;

  if (hits.length === 0) {
    return (
      <section className="mt-6" aria-label="Message search results">
        <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          Matching messages
        </h3>
        <p className="rounded-xl border border-dashed border-border px-4 py-6 text-center text-[13px] text-muted-foreground">
          No individual messages contain “{query}”. Matches above are from chat
          titles only.
        </p>
      </section>
    );
  }

  return (
    <section className="mt-6" aria-label="Message search results">
      <div className="mb-3 flex items-baseline justify-between gap-2">
        <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          Matching messages
        </h3>
        <span className="text-xs tabular-nums text-muted-foreground/80" aria-live="polite">
          {hits.length} {hits.length === 1 ? 'message' : 'messages'}
        </span>
      </div>

      <ul className="space-y-1.5">
        {visibleHits.map((hit) => (
          <li key={hit.message.id}>
            <button
              type="button"
              onClick={() => openAt(hit)}
              className="group flex w-full items-start gap-3 rounded-xl border border-border bg-card px-3.5 py-3 text-left transition-colors hover:border-brand-strong/50 hover:bg-muted/40 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-strong"
            >
              <span
                className={cn(
                  'mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg',
                  hit.message.role === 'user'
                    ? 'bg-foreground/5 text-foreground/70'
                    : 'bg-brand/20 text-brand-strong dark:text-brand'
                )}
                aria-hidden="true"
              >
                {hit.message.role === 'user' ? (
                  <User className="h-3.5 w-3.5" />
                ) : (
                  <Bot className="h-3.5 w-3.5" />
                )}
              </span>

              <span className="min-w-0 flex-1">
                <span className="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[13px]">
                  <span className="max-w-[220px] truncate font-medium">
                    {hit.chat.title || 'Untitled chat'}
                  </span>
                  <span className="text-[11px] uppercase tracking-wide text-muted-foreground/70">
                    {hit.message.role === 'user' ? 'You' : 'Assistant'}
                  </span>
                  <span className="text-[11px] text-muted-foreground/60">
                    {formatRelativeTime(hit.message.createdAt)}
                  </span>
                  {hit.matchCount > 1 && (
                    <span className="rounded-full bg-muted px-1.5 py-px text-[10px] tabular-nums text-muted-foreground">
                      ×{hit.matchCount}
                    </span>
                  )}
                </span>
                <span className="mt-1 block line-clamp-2 text-[13px] leading-relaxed text-muted-foreground">
                  {hit.parts.map((p, i) =>
                    p.hit ? (
                      <mark key={i}>{p.text}</mark>
                    ) : (
                      <span key={i}>{p.text}</span>
                    )
                  )}
                </span>
              </span>

              <ArrowRight
                className="mt-1.5 h-3.5 w-3.5 shrink-0 text-muted-foreground/40 transition-transform group-hover:translate-x-0.5 group-hover:text-brand-strong"
                aria-hidden="true"
              />
            </button>
          </li>
        ))}
      </ul>

      {hits.length > PAGE_SIZE && (
        <div className="mt-3 flex justify-center">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setExpanded((v) => !v)}
            aria-expanded={expanded}
          >
            <ChevronDown
              className={cn('h-4 w-4 transition-transform', expanded && 'rotate-180')}
            />
            {expanded
              ? 'Show fewer'
              : `Show ${Math.min(hits.length - PAGE_SIZE, 200 - PAGE_SIZE)} more`}
          </Button>
        </div>
      )}
    </section>
  );
}

/** Re-exported for the empty-history edge case (no messages anywhere). */
export function NoMessagesState() {
  return (
    <EmptyState
      icon={MessageSquareText}
      title="No messages yet"
      description="Once you start chatting, message-level search results will appear here."
    />
  );
}
