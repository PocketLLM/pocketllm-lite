'use client';

/**
 * InspectorPanel — the third column (xl+ screens), per plan §15.
 *
 * A live, at-a-glance context surface for the open conversation:
 *   1. Conversation — meta stats + in-chat message search (jump-to-message)
 *   2. Model       — active runtime/model card with capabilities
 *   3. Persona     — active persona summary (instructions excerpt)
 *   4. Memory      — enabled state + the memories injected into context
 *   5. Context     — honest token estimate of the visible conversation
 *   6. Knowledge   — retrieval scope + per-chat retrieval-mode pin
 *   7. Tools       — tool calls that ran in this chat, with outcomes
 *   8. Activity    — 14-day message sparkline + you-vs-PocketLLM split
 *   9. Tags        — tags applied to this chat
 *
 * Everything is read-only context + navigation; edits stay in their own
 * views. Hidden below xl (the layout degrades to two columns).
 */
import { useEffect, useMemo, useState } from 'react';
import {
  Activity as ActivityIcon,
  Search,
  Boxes,
  Sparkles,
  Brain,
  Gauge,
  Wrench,
  ChevronRight,
  Pin,
  CheckCircle2,
  XCircle,
  ArrowDown,
  MessageSquare,
  Tag as TagIcon,
  Plus,
  X,
  Paperclip,
  BookOpenText,
} from 'lucide-react';
import { useAppStore, useChatStore } from '@/lib/store/app-store';
import { memoryService } from '@/lib/services/memory-service';
import { chatService } from '@/lib/services/chat-service';
import { personaRepo, tagRepo, documentRepo } from '@/lib/core/db/repositories';
import { router } from '@/lib/core/router';
import { bus } from '@/lib/core/events/event-bus';
import { cn, estimateTokens, formatBytes } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import {
  ActivitySparkline,
  computeActivityWindow,
} from '@/features/app/shared/activity-sparkline';
import { RetrievalModeControl } from '@/features/app/chat/knowledge-scope';
import { settingsService } from '@/lib/services/settings-service';
import type { Chat, DocumentRecord, Memory, Persona, RetrievalMode, Tag, ToolEvent } from '@/lib/types/domain';

/* --------------------------- formatting ---------------------------- */

function relTime(ts: number): string {
  const diff = Date.now() - ts;
  const mins = Math.floor(diff / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `${days}d ago`;
  return new Date(ts).toLocaleDateString();
}

/* ------------------------------ shell ------------------------------ */

export function InspectorPanel({
  chat,
  branches,
  onChatChanged,
}: {
  chat: Chat;
  branches: import('@/lib/types/domain').ChatBranch[];
  /** Notify the parent ChatView that tags changed (refresh chat state). */
  onChatChanged?: () => void;
}) {
  const { messages, toolEvents } = useChatStore();
  const models = useAppStore((s) => s.models);

  /* ---- derived conversation stats ---- */
  const stats = useMemo(() => {
    const userMsgs = messages.filter((m) => m.role === 'user');
    const assistantMsgs = messages.filter((m) => m.role === 'assistant');
    const tokenEstimate = messages.reduce((sum, m) => sum + estimateTokens(m.content), 0);
    const measured = assistantMsgs.reduce(
      (sum, m) => sum + (m.metrics?.tokensOut ?? 0),
      0
    );
    const speeds = assistantMsgs
      .map((m) => m.metrics?.tokensPerSecond ?? 0)
      .filter((v) => v > 0);
    const avgSpeed = speeds.length
      ? Math.round(speeds.reduce((a, b) => a + b, 0) / speeds.length)
      : 0;
    return { userMsgs, assistantMsgs, tokenEstimate, measured, avgSpeed };
  }, [messages]);

  /* ---- in-chat message search ---- */
  const [query, setQuery] = useState('');
  const hits = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [];
    return messages
      .filter((m) => m.content.toLowerCase().includes(q))
      .slice(0, 20);
  }, [messages, query]);

  /* ---- 14-day activity window (shared computation) ---- */
  const activity = useMemo(() => {
    const win = computeActivityWindow(messages.map((m) => m.createdAt));
    const totalWords = messages.reduce((sum, m) => {
      const words = m.content.trim();
      return sum + (words ? words.split(/\s+/).length : 0);
    }, 0);
    return { ...win, totalWords };
  }, [messages]);

  /* ---- knowledge scope documents (names for the scoped ids) ---- */
  const [allDocs, setAllDocs] = useState<DocumentRecord[]>([]);
  useEffect(() => {
    let cancelled = false;
    const load = () => {
      void documentRepo.getAll().then((list) => {
        if (!cancelled) setAllDocs(list);
      });
    };
    load();
    const unsub = bus.on('documents:changed', load);
    return () => {
      cancelled = true;
      unsub();
    };
  }, []);
  const readyDocs = useMemo(() => allDocs.filter((d) => d.status === 'ready'), [allDocs]);
  const scopeDocs = useMemo(() => {
    const scope = chat.knowledgeDocIds ?? [];
    if (scope.length === 0) return [];
    const byId = new Map(allDocs.map((d) => [d.id, d] as const));
    return scope.map((id) => byId.get(id) ?? null);
  }, [chat.knowledgeDocIds, allDocs]);

  const jumpTo = (messageId: string) => {
    const el = document.querySelector<HTMLElement>(
      `[data-message-id="${messageId}"]`
    );
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      // Brief highlight pulse so the target is unmistakable.
      el.classList.add('message-flash');
      window.setTimeout(() => el.classList.remove('message-flash'), 1400);
    }
  };

  /* ---- persona ---- */
  const [persona, setPersona] = useState<Persona | null>(null);
  useEffect(() => {
    let cancelled = false;
    if (chat.personaId) {
      void personaRepo.get(chat.personaId).then((p) => {
        if (!cancelled) setPersona(p ?? null);
      });
    } else {
      setPersona(null);
    }
    return () => {
      cancelled = true;
    };
  }, [chat.personaId]);

  /* ---- memories (live) ---- */
  const [memories, setMemories] = useState<Memory[]>([]);
  useEffect(() => {
    let cancelled = false;
    const load = () =>
      void memoryService.active().then((all) => {
        if (!cancelled) setMemories(all);
      });
    load();
    return bus.on('memories:changed', load);
  }, []);

  /* ---- tool events grouped ---- */
  const toolSummary = useMemo(() => {
    const byTool = new Map<string, { ok: number; failed: number }>();
    for (const ev of toolEvents) {
      const entry = byTool.get(ev.tool) ?? { ok: 0, failed: 0 };
      if (ev.status === 'succeeded') entry.ok++;
      if (ev.status === 'failed' || ev.status === 'denied') entry.failed++;
      byTool.set(ev.tool, entry);
    }
    return [...byTool.entries()];
  }, [toolEvents]);

  /* ---- attachments across this chat ---- */
  const attachments = useMemo(
    () =>
      messages
        .flatMap((m) => m.attachments.map((a) => ({ attachment: a, message: m })))
        .slice(0, 30),
    [messages]
  );

  /* ---- tags (live) ---- */
  const [tagMap, setTagMap] = useState<Map<string, Tag>>(new Map());
  useEffect(() => {
    let cancelled = false;
    const load = () =>
      void tagRepo.getAll().then((all) => {
        if (!cancelled) setTagMap(new Map(all.map((t) => [t.id, t])));
      });
    load();
    return bus.on('tags:changed', load);
  }, []);

  const chatTags = chat.tags
    .map((id) => tagMap.get(id))
    .filter((t): t is Tag => Boolean(t));
  const unassignedTags = [...tagMap.values()]
    .filter((t) => !chat.tags.includes(t.id))
    .sort((a, b) => a.name.localeCompare(b.name));

  const [addingTag, setAddingTag] = useState(false);

  const addTag = async (tag: Tag) => {
    try {
      await chatService.updateChat(chat.id, { tags: [...chat.tags, tag.id] });
      onChatChanged?.();
    } catch (err) {
      toast({
        title: 'Could not add tag',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    }
  };

  const removeTag = async (tag: Tag) => {
    try {
      await chatService.updateChat(chat.id, {
        tags: chat.tags.filter((t) => t !== tag.id),
      });
      onChatChanged?.();
    } catch (err) {
      toast({
        title: 'Could not remove tag',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    }
  };

  const activeModel = models.find((m) => m.id === chat.modelId);
  /* Real context window when the runtime reports it; honest fallback. */
  const contextLimit =
    activeModel?.contextLimit ?? null;
  const contextScale = contextLimit ?? 8192;
  const contextPct = Math.min(100, Math.round((stats.tokenEstimate / contextScale) * 100));
  const fmtK = (n: number) =>
    n >= 1000 ? `${Math.round(n / 1000)}k` : String(n);

  return (
    <div
      className="flex h-full w-[318px] shrink-0 flex-col overflow-y-auto border-l border-border bg-sidebar/40 scrollbar-slim"
      aria-label="Conversation inspector"
    >
      {/* Conversation */}
      <InspectorSection
        icon={MessageSquare}
        title="Conversation"
        action={{
          label: 'Full history',
          onClick: () => router.navigate('/app/chats'),
        }}
      >
        <dl className="grid grid-cols-2 gap-1.5">
          <Stat label="Messages" value={String(messages.length)} />
          <Stat label="Branches" value={String(branches.length)} />
          <Stat label="Started" value={relTime(chat.createdAt)} />
          <Stat
            label="Avg speed"
            value={stats.avgSpeed ? `${stats.avgSpeed} tok/s` : '—'}
          />
        </dl>

        {/* In-chat search */}
        <div className="mt-3">
          <div className="relative">
            <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search this conversation"
              aria-label="Search messages in this conversation"
              className="w-full rounded-lg border border-border bg-background py-1.5 pl-8 pr-3 text-[12.5px] outline-none transition-colors placeholder:text-muted-foreground/75 focus:border-brand-strong"
            />
          </div>
          {query.trim() && (
            <ul className="mt-2 space-y-1">
              {hits.length === 0 && (
                <li className="px-1 py-1.5 text-[11.5px] text-muted-foreground">
                  No messages match “{query.trim()}”.
                </li>
              )}
              {hits.map((m) => (
                <li key={m.id}>
                  <button
                    onClick={() => jumpTo(m.id)}
                    className="group flex w-full items-start gap-2 rounded-lg border border-transparent px-2 py-1.5 text-left transition-colors hover:border-border hover:bg-background"
                  >
                    <span
                      className={cn(
                        'mt-0.5 shrink-0 rounded px-1.5 py-0.5 text-[9.5px] font-semibold uppercase tracking-wide',
                        m.role === 'user'
                          ? 'bg-primary text-primary-foreground'
                          : 'bg-muted text-muted-foreground'
                      )}
                    >
                      {m.role === 'user' ? 'You' : 'AI'}
                    </span>
                    <span className="min-w-0 flex-1 truncate text-[12px] text-muted-foreground">
                      {m.content.slice(0, 90)}
                    </span>
                    <ArrowDown className="mt-0.5 h-3 w-3 shrink-0 text-muted-foreground/40 transition-colors group-hover:text-brand-strong" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </InspectorSection>

      {/* Activity */}
      <InspectorSection icon={ActivityIcon} title="Activity">
        {messages.length === 0 ? (
          <EmptyHint>
            No messages yet — the chart fills in as the conversation grows.
          </EmptyHint>
        ) : (
          <>
            <div className="rounded-xl border border-border bg-background p-3">
              <div className="flex items-baseline justify-between">
                <span className="text-[11px] text-muted-foreground">
                  Last 14 days
                </span>
                <span className="font-mono text-[12px] tabular-nums">
                  {activity.inWindow} message
                  {activity.inWindow === 1 ? '' : 's'}
                </span>
              </div>
              {/* Sparkline — shared component (also used by History). */}
              <ActivitySparkline
                window={activity}
                ariaContext="in this conversation"
                className="mt-2"
              />
              <div className="mt-1 flex items-center justify-between text-[9.5px] text-muted-foreground/80">
                <span>{activity.days[0].label}</span>
                <span className="flex items-center gap-1">
                  <span className="h-1.5 w-1.5 rounded-sm bg-brand-strong" aria-hidden />
                  today
                </span>
                <span>{activity.days[activity.days.length - 1].label}</span>
              </div>
            </div>

            {/* You vs PocketLLM split */}
            <div className="mt-2.5">
              {(() => {
                const total = messages.length;
                const userPct = total
                  ? Math.round((stats.userMsgs.length / total) * 100)
                  : 0;
                return (
                  <>
                    <div
                      className="flex h-1.5 overflow-hidden rounded-full bg-muted"
                      role="img"
                      aria-label={`You wrote ${userPct}% of the messages, PocketLLM ${100 - userPct}%.`}
                    >
                      <div
                        className="h-full bg-brand transition-all duration-500"
                        style={{ width: `${userPct}%` }}
                      />
                      <div
                        className="h-full bg-muted-foreground/65 transition-all duration-500"
                        style={{ width: `${100 - userPct}%` }}
                      />
                    </div>
                    <div className="mt-1.5 flex items-center justify-between text-[10.5px] text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <span className="h-1.5 w-1.5 rounded-sm bg-brand" aria-hidden />
                        You · {stats.userMsgs.length} ({userPct}%)
                      </span>
                      <span className="flex items-center gap-1">
                        PocketLLM · {stats.assistantMsgs.length} ({100 - userPct}%)
                        <span className="h-1.5 w-1.5 rounded-sm bg-muted-foreground/50" aria-hidden />
                      </span>
                    </div>
                  </>
                );
              })()}
            </div>

            <dl className="mt-2.5 grid grid-cols-2 gap-1.5">
              <Stat
                label="Words"
                value={activity.totalWords.toLocaleString()}
              />
              <Stat
                label="Avg / message"
                value={
                  messages.length
                    ? `${Math.round(activity.totalWords / messages.length)} words`
                    : '—'
                }
              />
            </dl>
          </>
        )}
      </InspectorSection>

      {/* Tags */}
      <InspectorSection
        icon={TagIcon}
        title="Tags"
        action={{
          label: 'Tags',
          onClick: () => router.navigate('/app/tags'),
        }}
      >
        <div className="flex flex-wrap items-center gap-1.5">
          {chatTags.map((tag) => (
            <span
              key={tag.id}
              className="group/tag inline-flex items-center gap-1.5 rounded-full border border-border bg-background py-1 pl-2 pr-1 text-[11px]"
            >
              <span
                className="h-1.5 w-1.5 rounded-full"
                style={{ backgroundColor: tag.color }}
                aria-hidden="true"
              />
              {tag.name}
              <button
                onClick={() => void removeTag(tag)}
                aria-label={`Remove tag ${tag.name} from this chat`}
                className="rounded-full p-0.5 text-muted-foreground/50 transition-colors hover:bg-destructive/10 hover:text-destructive"
              >
                <X className="h-2.5 w-2.5" />
              </button>
            </span>
          ))}

          {unassignedTags.length > 0 && (
            <span className="relative">
              <button
                onClick={() => setAddingTag((v) => !v)}
                aria-expanded={addingTag}
                aria-label="Add a tag to this chat"
                className={cn(
                  'inline-flex items-center gap-1 rounded-full border px-2 py-1 text-[11px] transition-colors',
                  addingTag
                    ? 'border-brand-strong text-brand-strong'
                    : 'border-dashed border-border text-muted-foreground hover:border-brand-strong/60 hover:text-foreground'
                )}
              >
                <Plus className="h-2.5 w-2.5" />
                Add
              </button>
              {addingTag && (
                <div
                  role="listbox"
                  aria-label="Available tags"
                  className="absolute right-0 top-[calc(100%+4px)] z-30 w-44 rounded-xl border border-border bg-card p-1 shadow-lg"
                >
                  {unassignedTags.map((tag) => (
                    <button
                      key={tag.id}
                      role="option"
                      aria-selected={false}
                      onClick={() => {
                        setAddingTag(false);
                        void addTag(tag);
                      }}
                      className="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left text-[12px] transition-colors hover:bg-muted"
                    >
                      <span
                        className="h-2 w-2 shrink-0 rounded-full"
                        style={{ backgroundColor: tag.color }}
                        aria-hidden="true"
                      />
                      <span className="truncate">{tag.name}</span>
                    </button>
                  ))}
                </div>
              )}
            </span>
          )}
        </div>
        {chatTags.length === 0 && unassignedTags.length === 0 && (
          <EmptyHint>
            No tags yet. Create tags in the Tags manager, then attach them here
            to group conversations.
          </EmptyHint>
        )}
      </InspectorSection>

      {/* Model */}
      <InspectorSection
        icon={Boxes}
        title="Model"
        action={{ label: 'Models', onClick: () => router.navigate('/app/models') }}
      >
        <div className="rounded-xl border border-border bg-background p-3">
          <p className="text-[13px] font-medium leading-tight">
            {activeModel?.label ?? chat.modelId}
          </p>
          <p className="mt-0.5 text-[11px] text-muted-foreground">
            {activeModel?.detail ?? `runtime · ${chat.runtimeId}`}
          </p>
          <div className="mt-2 flex flex-wrap gap-1">
            <Pill>{chat.runtimeId}</Pill>
            {activeModel?.supportsVision && <Pill accent>vision</Pill>}
            <Pill>tools</Pill>
          </div>
        </div>
      </InspectorSection>

      {/* Persona */}
      <InspectorSection
        icon={Sparkles}
        title="Persona"
        action={{
          label: 'Personas',
          onClick: () => router.navigate('/app/personas'),
        }}
      >
        {persona ? (
          <div className="rounded-xl border border-border bg-background p-3">
            <p className="text-[13px] font-medium leading-tight">
              <span className="mr-1.5">{persona.emoji}</span>
              {persona.name}
            </p>
            {persona.instructions && (
              <p className="mt-1.5 line-clamp-4 text-[11.5px] leading-relaxed text-muted-foreground">
                {persona.instructions}
              </p>
            )}
            <div className="mt-2 flex flex-wrap gap-1">
              {persona.temperature != null && (
                <Pill>temp {persona.temperature.toFixed(1)}</Pill>
              )}
              {persona.modelId && <Pill>own model</Pill>}
            </div>
          </div>
        ) : (
          <EmptyHint>
            No persona — the default composed system prompt is used.
          </EmptyHint>
        )}
      </InspectorSection>

      {/* Memory */}
      <InspectorSection
        icon={Brain}
        title="Memory"
        action={{
          label: 'Memories',
          onClick: () => router.navigate('/app/memories'),
        }}
      >
        {!chat.memoryEnabled ? (
          <EmptyHint>
            Memory is paused for this chat. Nothing is extracted or retrieved.
          </EmptyHint>
        ) : memories.length === 0 ? (
          <EmptyHint>
            Memory is on, but no active memories match your confidence
            threshold yet.
          </EmptyHint>
        ) : (
          <ul className="space-y-1.5">
            {memories.slice(0, 4).map((m) => (
              <li
                key={m.id}
                className="flex items-start gap-2 rounded-lg border border-border bg-background px-2.5 py-2"
              >
                {m.pinned && (
                  <Pin className="mt-0.5 h-3 w-3 shrink-0 text-brand-strong" />
                )}
                <span className="min-w-0 flex-1 text-[12px] leading-snug">
                  {m.fact}
                </span>
                <span className="shrink-0 font-mono text-[9.5px] text-muted-foreground/70">
                  {m.confidence.toFixed(1)}
                </span>
              </li>
            ))}
            {memories.length > 4 && (
              <li className="px-1 text-[11px] text-muted-foreground">
                + {memories.length - 4} more in context
              </li>
            )}
          </ul>
        )}
      </InspectorSection>

      {/* Context usage */}
      <InspectorSection
        icon={Gauge}
        title="Context"
        action={{
          label: 'Lab',
          onClick: () => router.navigate('/app/lab/prompt'),
        }}
      >
        <div className="rounded-xl border border-border bg-background p-3">
          <div className="flex items-baseline justify-between">
            <span className="text-[11px] text-muted-foreground">
              Estimated context
            </span>
            <span className="font-mono text-[12px] tabular-nums">
              ~{stats.tokenEstimate.toLocaleString()} tok
            </span>
          </div>
          <div
            className="mt-2 h-1.5 overflow-hidden rounded-full bg-muted"
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={contextPct}
            aria-label="Estimated context usage"
          >
            <div
              className={cn(
                'h-full rounded-full transition-all duration-500',
                contextPct > 80 ? 'bg-warning' : 'bg-brand'
              )}
              style={{ width: `${Math.max(3, contextPct)}%` }}
            />
          </div>
          <p className="mt-1.5 text-[10.5px] leading-relaxed text-muted-foreground/80">
            Rough estimate (chars ÷ 4) of the visible conversation
            {contextLimit
              ? ` against this model's ${fmtK(contextLimit)}-token window`
              : ' against an assumed 8k window (this runtime does not report one)'}
            . Measured tokens:{' '}
            <span className="font-mono">
              {stats.measured.toLocaleString()}
            </span>
            {stats.avgSpeed > 0 && (
              <>
                {' '}· avg <span className="font-mono">{stats.avgSpeed} tok/s</span>
              </>
            )}
            .
          </p>
        </div>
      </InspectorSection>

      {/* Knowledge scope */}
      <InspectorSection
        icon={BookOpenText}
        title="Knowledge"
        action={{
          label: 'Library',
          onClick: () => router.navigate('/app/knowledge'),
        }}
      >
        {scopeDocs.length === 0 ? (
          <EmptyHint>
            Global scope — retrieval searches all{' '}
            {readyDocs.length === 0
              ? 'documents'
              : `${readyDocs.length} ready document${readyDocs.length > 1 ? 's' : ''}`}
            . Scope this chat from the book icon in the composer.
          </EmptyHint>
        ) : (
          <>
            <p className="mb-1.5 text-[10.5px] leading-relaxed text-muted-foreground">
              Retrieval searches only these document
              {scopeDocs.length > 1 ? 's' : ''}:
            </p>
            <ul className="space-y-1">
              {scopeDocs.map((doc, i) => (
                <li key={(chat.knowledgeDocIds ?? [])[i]}>
                  <button
                    onClick={() => doc && router.navigate(`/app/knowledge/${doc.id}`)}
                    disabled={!doc}
                    className="group flex w-full items-center gap-2 rounded-lg border border-brand/30 bg-background px-2.5 py-1.5 text-left transition-colors hover:border-brand-strong/60 disabled:cursor-default disabled:opacity-60"
                    title={doc ? `Open ${doc.name} in Knowledge` : 'This document is no longer available'}
                  >
                    <BookOpenText className="h-3 w-3 shrink-0 text-brand-strong" aria-hidden="true" />
                    <span className="min-w-0 flex-1">
                      <span className={cn('block truncate text-[12px] font-medium', !doc && 'italic text-muted-foreground')}>
                        {doc?.name ?? 'Removed document'}
                      </span>
                      {doc && (
                        <span className="block text-[10px] text-muted-foreground tabular-nums">
                          {doc.chunkCount} chunks · {relTime(doc.indexedAt ?? doc.createdAt)}
                        </span>
                      )}
                    </span>
                    <ChevronRight className="h-3 w-3 shrink-0 text-muted-foreground/40 transition-colors group-hover:text-brand-strong" />
                  </button>
                </li>
              ))}
            </ul>
            <button
              type="button"
              onClick={() => {
                void chatService.updateChat(chat.id, { knowledgeDocIds: [] }).then(() => {
                  onChatChanged?.();
                  toast({
                    title: 'Scope reset',
                    description: 'Retrieval searches all ready documents again.',
                  });
                });
              }}
              className="mt-2 text-[11px] font-medium text-muted-foreground underline-offset-2 transition-colors hover:text-foreground hover:underline"
            >
              Reset to all documents
            </button>
          </>
        )}

        {/* Retrieval mode — pinned per chat, mirrors the composer picker (footer). */}
        <div className="mt-2.5 border-t border-border/60 pt-2.5">
          <div className="mb-1.5 flex items-center justify-between">
            <span className="text-[10.5px] font-semibold uppercase tracking-wide text-muted-foreground">
              Retrieval mode
            </span>
            <span
              className={cn(
                'text-[10px] font-medium',
                chat.retrievalMode ? 'text-brand-strong' : 'text-muted-foreground/70'
              )}
            >
              {chat.retrievalMode
                ? `pinned · ${chat.retrievalMode}`
                : `settings · ${settingsService.get().knowledge.defaultRetrievalMode}`}
            </span>
          </div>
          <RetrievalModeControl
            mode={chat.retrievalMode ?? null}
            onChange={(mode: RetrievalMode | null) => {
              void chatService.updateChat(chat.id, { retrievalMode: mode }).then(() => {
                onChatChanged?.();
                toast({
                  title: mode ? `Retrieval mode pinned — ${mode}` : 'Retrieval mode reset',
                  description: mode
                    ? 'This chat keeps its ranking strategy even if Settings change.'
                    : 'This chat follows the Settings default again.',
                });
              });
            }}
          />
        </div>
      </InspectorSection>

      {/* Tools */}
      <InspectorSection
        icon={Wrench}
        title="Tools"
        action={{
          label: 'Skills',
          onClick: () => router.navigate('/app/skills'),
        }}
      >
        {toolSummary.length === 0 ? (
          <EmptyHint>
            No tool calls yet in this chat. When the model calls a tool you
            approve it inline.
          </EmptyHint>
        ) : (
          <ul className="space-y-1">
            {toolSummary.map(([tool, counts]) => (
              <li
                key={tool}
                className="flex items-center gap-2 rounded-lg border border-border bg-background px-2.5 py-1.5"
              >
                <span className="min-w-0 flex-1 truncate font-mono text-[11.5px]">
                  {tool}
                </span>
                {counts.ok > 0 && (
                  <span className="flex items-center gap-1 text-[10.5px] text-success">
                    <CheckCircle2 className="h-3 w-3" />
                    {counts.ok}
                  </span>
                )}
                {counts.failed > 0 && (
                  <span className="flex items-center gap-1 text-[10.5px] text-destructive">
                    <XCircle className="h-3 w-3" />
                    {counts.failed}
                  </span>
                )}
              </li>
            ))}
          </ul>
        )}
      </InspectorSection>

      {/* Attachments */}
      <InspectorSection
        icon={Paperclip}
        title="Attachments"
      >
        {attachments.length === 0 ? (
          <EmptyHint>
            No attachments in this chat. Files added to messages appear here.
          </EmptyHint>
        ) : (
          <ul className="space-y-1">
            {attachments.map(({ attachment, message }) => (
              <li key={attachment.id}>
                <button
                  onClick={() => jumpTo(message.id)}
                  className="group flex w-full items-center gap-2 rounded-lg border border-border bg-background px-2.5 py-1.5 text-left transition-colors hover:border-brand-strong/50"
                >
                  <span
                    className={cn(
                      'flex h-6 w-6 shrink-0 items-center justify-center rounded-md text-[9px] font-bold uppercase',
                      attachment.kind === 'image'
                        ? 'bg-brand/20 text-brand-strong'
                        : 'bg-muted text-muted-foreground'
                    )}
                    aria-hidden="true"
                  >
                    {attachment.kind === 'image' ? 'IMG' : 'FILE'}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[12px] font-medium">
                      {attachment.name}
                    </span>
                    <span className="block text-[10px] text-muted-foreground">
                      {formatBytes(attachment.sizeBytes)} ·{' '}
                      {message.role === 'user' ? 'your message' : 'assistant'}
                    </span>
                  </span>
                  <ArrowDown className="h-3 w-3 shrink-0 text-muted-foreground/40 transition-colors group-hover:text-brand-strong" />
                </button>
              </li>
            ))}
          </ul>
        )}
      </InspectorSection>

      <p className="mt-auto px-4 pb-4 pt-2 text-[10px] leading-relaxed text-muted-foreground/60">
        The inspector shows live context for this conversation. It never sends
        anything anywhere — it reads the same local database the chat uses.
      </p>
    </div>
  );
}

/* ---------------------------- primitives --------------------------- */

function InspectorSection({
  icon: Icon,
  title,
  action,
  children,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  action?: { label: string; onClick: () => void };
  children: React.ReactNode;
}) {
  return (
    <section className="border-b border-border/60 px-4 py-3.5">
      <header className="flex items-center gap-2">
        <Icon className="h-3.5 w-3.5 text-brand-strong" />
        <h3 className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
          {title}
        </h3>
        {action && (
          <button
            onClick={action.onClick}
            className="ml-auto flex items-center gap-0.5 rounded px-1 py-0.5 text-[10.5px] text-muted-foreground transition-colors hover:text-brand-strong"
          >
            {action.label}
            <ChevronRight className="h-3 w-3" />
          </button>
        )}
      </header>
      <div className="mt-2.5">{children}</div>
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg bg-background/60 px-2.5 py-1.5">
      <dt className="text-[9.5px] font-medium uppercase tracking-wide text-muted-foreground/70">
        {label}
      </dt>
      <dd className="mt-0.5 text-[12.5px] font-medium tabular-nums">{value}</dd>
    </div>
  );
}

function Pill({
  children,
  accent,
}: {
  children: React.ReactNode;
  accent?: boolean;
}) {
  return (
    <span
      className={cn(
        'rounded-full border px-1.5 py-0.5 text-[9.5px] font-medium',
        accent
          ? 'border-brand-strong/60 text-brand-strong'
          : 'border-border text-muted-foreground'
      )}
    >
      {children}
    </span>
  );
}

function EmptyHint({ children }: { children: React.ReactNode }) {
  return (
    <p className="rounded-lg border border-dashed border-border bg-background/40 px-3 py-2.5 text-[11.5px] leading-relaxed text-muted-foreground">
      {children}
    </p>
  );
}
