'use client';

/**
 * Knowledge scope — the per-chat retrieval controls (plan §41 follow-up).
 *
 * A chat can restrict document retrieval to a specific set of Knowledge
 * documents (`Chat.knowledgeDocIds`). Empty list = global scope (search
 * all ready documents — the default, unchanged behavior). Non-empty =
 * retrieval only searches the listed documents.
 *
 * A chat can also pin its retrieval ranking mode (`Chat.retrievalMode`)
 * independently of the global Settings default — null = inherit.
 *
 * Exported pieces:
 *  - `KnowledgeScopePicker` — composer button + popover checklist with a
 *    retrieval-mode segmented control in its footer and full keyboard
 *    navigation (arrows / Home / End / Enter).
 *  - `KnowledgeScopeChips` — the chip strip above the composer: one chip
 *    per scoped document (click opens the document, X detaches) plus a
 *    pinned-mode chip with reset.
 *  - `RetrievalModeControl` — the shared segmented control used by the
 *    picker footer and the inspector's Knowledge section.
 */
import { useEffect, useMemo, useRef, useState } from 'react';
import {
  BookOpenText,
  Check,
  Globe2,
  Library,
  SlidersHorizontal,
  X,
} from 'lucide-react';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';
import { bus } from '@/lib/core/events/event-bus';
import { router } from '@/lib/core/router';
import { documentService } from '@/lib/services/document-service';
import { settingsService } from '@/lib/services/settings-service';
import { DocumentIcon, typeLabel } from '@/features/app/knowledge/helpers';
import type { Chat, DocumentRecord, RetrievalMode } from '@/lib/types/domain';

/* ------------------------- data hook (shared) ---------------------- */

/**
 * Loads all ready documents and keeps them fresh on
 * `documents:changed` (import / delete / reindex).
 */
export function useReadyDocuments(): DocumentRecord[] {
  const [docs, setDocs] = useState<DocumentRecord[]>([]);

  useEffect(() => {
    let alive = true;
    const load = () => {
      void documentService.list().then((list) => {
        if (alive) setDocs(list.filter((d) => d.status === 'ready'));
      });
    };
    load();
    const unsub = bus.on('documents:changed', load);
    return () => {
      alive = false;
      unsub();
    };
  }, []);

  return docs;
}

/* --------------------- retrieval-mode control ---------------------- */

/**
 * Compact segmented control: Auto (inherit the Settings default) plus the
 * three concrete ranking strategies. Shared by the picker footer and the
 * inspector's Knowledge section so both stay visually identical.
 */
export function RetrievalModeControl({
  mode,
  onChange,
  size = 'sm',
}: {
  /** Current override — null means "inherit the global default". */
  mode: RetrievalMode | null;
  onChange: (mode: RetrievalMode | null) => void;
  /** `sm` for popover/inspector rows, `xs` for tighter layouts. */
  size?: 'sm' | 'xs';
}) {
  const inherited = settingsService.get().knowledge.defaultRetrievalMode;
  const options: Array<{ value: RetrievalMode | null; label: string; hint: string }> = [
    {
      value: null,
      label: 'Auto',
      hint: `Follow Settings — currently ${inherited}`,
    },
    { value: 'lexical', label: 'Lexical', hint: 'BM25 keyword matching — exact terms' },
    { value: 'semantic', label: 'Semantic', hint: 'Local TF-IDF similarity' },
    { value: 'hybrid', label: 'Hybrid', hint: 'Fusion of lexical + vectors' },
  ];

  return (
    <div
      className={cn(
        'grid w-full grid-cols-4 gap-1 rounded-lg border border-border bg-background p-1',
        size === 'xs' && 'p-0.5'
      )}
      role="radiogroup"
      aria-label="Retrieval mode for this chat"
    >
      {options.map((opt) => {
        const active = mode === opt.value;
        return (
          <button
            key={opt.label}
            type="button"
            role="radio"
            aria-checked={active}
            title={opt.hint}
            onClick={() => onChange(opt.value)}
            className={cn(
              'rounded-md text-center font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/60',
              size === 'sm'
                ? 'px-1 py-1 text-[11px]'
                : 'px-0.5 py-0.5 text-[10.5px]',
              active
                ? 'bg-brand text-brand-foreground shadow-sm'
                : 'text-muted-foreground hover:bg-muted hover:text-foreground'
            )}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}

/* --------------------------- picker -------------------------------- */

/**
 * Composer affordance that opens the scope checklist. The trigger button
 * gets the brand accent while a scope is active so the state is visible
 * at a glance without opening the popover.
 *
 * `open`/`onOpenChange` make the popover controlled — ChatView drives it
 * so the `/scope` slash command can open it from the keyboard.
 */
export function KnowledgeScopePicker({
  chat,
  docs,
  onChange,
  onModeChange,
  open,
  onOpenChange,
}: {
  chat: Chat;
  docs: DocumentRecord[];
  onChange: (docIds: string[]) => void;
  onModeChange: (mode: RetrievalMode | null) => void;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
}) {
  const [openLocal, setOpenLocal] = useState(false);
  const isOpen = open ?? openLocal;
  const setOpen = onOpenChange ?? setOpenLocal;
  const scope = chat.knowledgeDocIds ?? [];
  const scoped = scope.length > 0;
  const pinnedMode = chat.retrievalMode ?? null;

  const byId = useMemo(() => new Map(docs.map((d) => [d.id, d] as const)), [docs]);
  /** Docs in scope that are no longer ready/deleted — still listed honestly. */
  const missing = useMemo(
    () => scope.filter((id) => !byId.has(id)),
    [scope, byId]
  );

  const toggle = (docId: string) => {
    const next = scope.includes(docId)
      ? scope.filter((id) => id !== docId)
      : [...scope, docId];
    onChange(next);
  };

  /* Roving keyboard navigation over the option rows: ↑/↓ cycles, Home/End
   * jump, Enter/Space activate the focused row (native button behaviour). */
  const listRef = useRef<HTMLDivElement>(null);
  const handleListKeyDown = (e: React.KeyboardEvent<HTMLDivElement>) => {
    if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(e.key)) return;
    const options = Array.from(
      listRef.current?.querySelectorAll<HTMLButtonElement>('button[role="option"]') ?? []
    );
    if (options.length === 0) return;
    e.preventDefault();
    const idx = options.indexOf(document.activeElement as HTMLButtonElement);
    let next: number;
    if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = options.length - 1;
    else {
      const dir = e.key === 'ArrowDown' ? 1 : -1;
      next = idx === -1 ? (dir === 1 ? 0 : options.length - 1) : (idx + dir + options.length) % options.length;
    }
    options[next].focus();
  };

  return (
    <Popover open={isOpen} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <button
          type="button"
          className={cn(
            'relative flex h-9 w-9 items-center justify-center rounded-lg transition-colors active:scale-90',
            'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/60',
            scoped || pinnedMode
              ? 'text-brand-strong hover:bg-brand/15 hover:text-brand-strong'
              : 'text-muted-foreground hover:bg-muted hover:text-foreground'
          )}
          title={
            scoped
              ? `Knowledge scope: ${scope.length} document${scope.length > 1 ? 's' : ''} — retrieval only searches them`
              : 'Scope Knowledge retrieval — currently searching all documents'
          }
          aria-label="Set knowledge retrieval scope"
          aria-haspopup="dialog"
        >
          <BookOpenText className="h-4 w-4" />
          {/* Count badge — the scope state at a glance, even mid-conversation. */}
          {scoped && (
            <span
              className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-brand px-1 text-[9px] font-bold leading-none text-brand-foreground tabular-nums ring-1 ring-card"
              aria-hidden="true"
            >
              {scope.length}
            </span>
          )}
        </button>
      </PopoverTrigger>
      <PopoverContent
        align="start"
        side="top"
        className="w-80 rounded-xl border-border p-0 shadow-lg"
        aria-label="Knowledge retrieval scope"
      >
        <div className="flex items-center gap-2 border-b border-border/60 px-3 py-2.5">
          <Library className="h-3.5 w-3.5 text-brand-strong" aria-hidden="true" />
          <span className="text-[12px] font-semibold tracking-wide uppercase text-foreground">
            Retrieval scope
          </span>
          {scoped && (
            <span className="ml-auto rounded-full border border-brand/50 bg-brand/10 px-1.5 py-0.5 text-[10px] font-medium text-brand-strong tabular-nums">
              {scope.length} scoped
            </span>
          )}
        </div>

        <div
          ref={listRef}
          className="max-h-72 overflow-y-auto p-1.5"
          role="listbox"
          aria-label="Documents"
          onKeyDown={handleListKeyDown}
        >
          {/* Global scope row — the default. */}
          <button
            type="button"
            role="option"
            aria-selected={!scoped}
            onClick={() => onChange([])}
            className={cn(
              'flex w-full items-center gap-2.5 rounded-lg px-2.5 py-2 text-left transition-colors',
              !scoped ? 'bg-brand-soft/70 dark:bg-brand/10' : 'hover:bg-muted/70'
            )}
          >
            <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-md border border-border bg-card">
              {!scoped && <Check className="h-3 w-3 text-brand-strong" />}
            </span>
            <Globe2 className="h-3.5 w-3.5 shrink-0 text-muted-foreground" aria-hidden="true" />
            <span className="min-w-0 flex-1">
              <span className="block truncate text-[12.5px] font-medium">All documents</span>
              <span className="block text-[10.5px] text-muted-foreground">
                Search every ready document — default
              </span>
            </span>
          </button>

          {docs.map((doc) => {
            const active = scope.includes(doc.id);
            return (
              <button
                key={doc.id}
                type="button"
                role="option"
                aria-selected={active}
                onClick={() => toggle(doc.id)}
                className={cn(
                  'flex w-full items-center gap-2.5 rounded-lg px-2.5 py-2 text-left transition-colors',
                  active ? 'bg-brand-soft/70 dark:bg-brand/10' : 'hover:bg-muted/70'
                )}
              >
                <span
                  className={cn(
                    'flex h-5 w-5 shrink-0 items-center justify-center rounded-md border transition-colors',
                    active ? 'border-brand-strong bg-brand text-brand-foreground' : 'border-border bg-card'
                  )}
                >
                  {active && <Check className="h-3 w-3" />}
                </span>
                <DocumentIcon
                  mimeType={doc.mimeType}
                  name={doc.name}
                  className={cn('h-3.5 w-3.5 shrink-0', active ? 'text-brand-strong' : 'text-muted-foreground')}
                />
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[12.5px] font-medium">{doc.name}</span>
                  <span className="block text-[10.5px] text-muted-foreground tabular-nums">
                    {typeLabel(doc)} · {doc.chunkCount} chunks
                  </span>
                </span>
              </button>
            );
          })}

          {/* Scoped ids that vanished (deleted / failed) — honest ghost rows. */}
          {missing.map((id) => (
            <button
              key={id}
              type="button"
              role="option"
              aria-selected={scope.includes(id)}
              onClick={() => toggle(id)}
              className="flex w-full items-center gap-2.5 rounded-lg px-2.5 py-2 text-left opacity-60 transition-colors hover:bg-muted/70"
              title="This document is no longer available — click to remove it from the scope"
            >
              <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-md border border-brand-strong bg-brand text-brand-foreground">
                <Check className="h-3 w-3" />
              </span>
              <span className="min-w-0 flex-1 text-[12.5px] font-medium italic">
                Removed document
              </span>
              <X className="h-3 w-3 shrink-0 text-muted-foreground" aria-hidden="true" />
            </button>
          ))}

          {docs.length === 0 && missing.length === 0 && (
            <p className="px-3 py-6 text-center text-[11.5px] leading-relaxed text-muted-foreground">
              No ready documents yet. Import files in Knowledge to scope
              this chat to them.
            </p>
          )}
        </div>

        {/* Retrieval mode — pinned per chat, independent of the scope. */}
        <div className="border-t border-border/60 px-3 py-2.5">
          <div className="mb-1.5 flex items-center gap-1.5">
            <SlidersHorizontal className="h-3 w-3 text-muted-foreground" aria-hidden="true" />
            <span className="text-[10.5px] font-semibold uppercase tracking-wide text-muted-foreground">
              Retrieval mode
            </span>
            {pinnedMode && (
              <span className="ml-auto text-[10px] font-medium text-brand-strong">pinned</span>
            )}
          </div>
          <RetrievalModeControl mode={pinnedMode} onChange={onModeChange} />
          <p className="mt-1 text-[10px] leading-snug text-muted-foreground/80">
            Applies to this chat only — Settings keeps the global default.
          </p>
        </div>

        {scoped && (
          <div className="border-t border-border/60 px-3 py-2">
            <button
              type="button"
              onClick={() => onChange([])}
              className="text-[11px] font-medium text-muted-foreground underline-offset-2 transition-colors hover:text-foreground hover:underline"
            >
              Reset to all documents
            </button>
          </div>
        )}
      </PopoverContent>
    </Popover>
  );
}

/* ----------------------------- chips -------------------------------- */

/**
 * Chip strip above the composer mirroring the attachment chips: one chip
 * per scoped document — clicking it opens the document in Knowledge, X
 * detaches it from the scope — plus a pinned-mode chip with reset.
 * Hidden entirely when the scope is global AND the mode is inherited.
 */
export function KnowledgeScopeChips({
  chat,
  docs,
  onChange,
  onModeChange,
}: {
  chat: Chat;
  docs: DocumentRecord[];
  onChange: (docIds: string[]) => void;
  onModeChange: (mode: RetrievalMode | null) => void;
}) {
  const scope = chat.knowledgeDocIds ?? [];
  const pinnedMode = chat.retrievalMode ?? null;
  if (scope.length === 0 && !pinnedMode) return null;

  const byId = new Map(docs.map((d) => [d.id, d] as const));

  return (
    <div className="mb-2.5 flex flex-wrap items-center gap-1.5" data-testid="knowledge-scope-chips">
      {scope.length > 0 && (
        <span className="inline-flex shrink-0 items-center gap-1 rounded-lg border border-brand/40 bg-brand-soft/50 px-2 py-1 text-[10.5px] font-semibold uppercase tracking-wide text-brand-strong dark:bg-brand/10 dark:text-brand">
          <BookOpenText className="h-3 w-3" aria-hidden="true" />
          Scope
        </span>
      )}
      {scope.map((id) => {
        const doc = byId.get(id);
        return (
          <span
            key={id}
            title={
              doc
                ? `${doc.name} — click to open in Knowledge`
                : 'This document is no longer available'
            }
            className="group/scope relative inline-flex items-center gap-1.5 rounded-lg border border-brand/30 bg-card px-2 py-1 text-[11px] text-foreground transition-colors hover:border-brand-strong/50 dark:border-brand/40"
          >
            <button
              type="button"
              disabled={!doc}
              onClick={() => doc && router.navigate(`/app/knowledge/${doc.id}`)}
              className="flex items-center gap-1.5 rounded-md py-0.5 pl-0.5 pr-0.5 transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/60 disabled:cursor-default"
              aria-label={doc ? `Open ${doc.name} in Knowledge` : 'Removed document'}
            >
              <DocumentIcon
                mimeType={doc?.mimeType ?? 'text/plain'}
                name={doc?.name ?? 'document'}
                className="h-3 w-3 text-brand-strong"
              />
              <span className={cn('max-w-[160px] truncate', !doc && 'italic text-muted-foreground')}>
                {doc?.name ?? 'Removed document'}
              </span>
            </button>
            <button
              type="button"
              onClick={() => onChange(scope.filter((x) => x !== id))}
              className="rounded p-0.5 text-muted-foreground transition-colors hover:bg-brand/15 hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/60"
              aria-label={`Remove ${doc?.name ?? 'removed document'} from scope`}
            >
              <X className="h-3 w-3" />
            </button>
          </span>
        );
      })}
      {pinnedMode && (
        <span
          title={`Retrieval ranking pinned to ${pinnedMode} for this chat`}
          className="inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-2 py-1 text-[11px] text-muted-foreground"
        >
          <SlidersHorizontal className="h-3 w-3 text-brand-strong" aria-hidden="true" />
          <span className="font-medium capitalize">{pinnedMode}</span>
          <span className="text-muted-foreground/60" aria-hidden="true">·</span>
          <span className="text-[10px] uppercase tracking-wide">mode</span>
          <button
            type="button"
            onClick={() => onModeChange(null)}
            className="rounded p-0.5 text-muted-foreground transition-colors hover:bg-brand/15 hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/60"
            aria-label="Reset retrieval mode to the Settings default"
            title="Follow the Settings default again"
          >
            <X className="h-3 w-3" />
          </button>
        </span>
      )}
    </div>
  );
}
