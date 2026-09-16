'use client';

/**
 * Shared helpers for the Knowledge feature: retrieval-mode metadata,
 * status badges, file-type icons, query highlighting and snippets.
 */
import { Fragment } from 'react';
import { FileCode, FileSpreadsheet, FileText } from 'lucide-react';
import { cn } from '@/lib/utils';
import type { DocumentStatus, RetrievalMode } from '@/lib/types/domain';

/* ------------------------- retrieval modes ------------------------ */

/** Honest, one-line descriptions of each local retrieval strategy. */
export const RETRIEVAL_MODES: ReadonlyArray<{
  value: RetrievalMode;
  label: string;
  hint: string;
}> = [
  {
    value: 'lexical',
    label: 'Lexical',
    hint: 'BM25 keyword matching — exact terms, always available.',
  },
  {
    value: 'semantic',
    label: 'Semantic',
    hint: 'Local TF-IDF vectors — word-overlap similarity, not a neural embedding model.',
  },
  {
    value: 'hybrid',
    label: 'Hybrid',
    hint: 'Fusion of lexical + local vectors — the best default.',
  },
];

export function modeHint(mode: RetrievalMode): string {
  return RETRIEVAL_MODES.find((m) => m.value === mode)?.hint ?? '';
}

/** True while the import pipeline is still working on a document. */
export function isWorkingStatus(status: DocumentStatus): boolean {
  return status === 'importing' || status === 'extracting' || status === 'chunking' || status === 'indexing';
}

/* --------------------------- file icons ---------------------------- */

/** FileText / FileSpreadsheet / FileCode icon picked from type + name. */
export function DocumentIcon({
  mimeType,
  name,
  className,
}: {
  mimeType: string;
  name: string;
  className?: string;
}) {
  const lower = name.toLowerCase();
  const isSheet = /\.(csv|tsv)$/.test(lower) || mimeType.includes('csv') || mimeType.includes('tab-separated');
  const isMarkdown = /\.(md|markdown)$/.test(lower) || mimeType.includes('markdown');
  const Icon = isSheet ? FileSpreadsheet : isMarkdown ? FileCode : FileText;
  return <Icon className={className} aria-hidden="true" />;
}

/** Short human label for the document type (PDF, Markdown, CSV…). */
export function typeLabel(doc: { mimeType: string; name: string }): string {
  const lower = doc.name.toLowerCase();
  if (doc.mimeType.includes('pdf') || /\.pdf$/i.test(lower)) return 'PDF';
  if (/\.(csv|tsv)$/i.test(lower) || doc.mimeType.includes('csv') || doc.mimeType.includes('tab-separated')) {
    return /\.tsv$/i.test(lower) ? 'TSV' : 'CSV';
  }
  if (/\.(md|markdown)$/i.test(lower) || doc.mimeType.includes('markdown')) return 'Markdown';
  if (doc.mimeType.includes('text/plain') || /\.txt$/i.test(lower)) return 'Text';
  return doc.mimeType || 'File';
}

/* --------------------------- status badge -------------------------- */

const STATUS_META: Record<DocumentStatus, { label: string; className: string }> = {
  importing: { label: 'Importing', className: 'border-brand-strong/50 bg-brand/15 text-foreground' },
  extracting: { label: 'Extracting', className: 'border-brand-strong/50 bg-brand/15 text-foreground' },
  chunking: { label: 'Chunking', className: 'border-brand-strong/50 bg-brand/15 text-foreground' },
  indexing: { label: 'Indexing', className: 'border-brand-strong/50 bg-brand/15 text-foreground' },
  ready: { label: 'Ready', className: 'border-success/30 text-success' },
  failed: { label: 'Failed', className: 'border-destructive/30 text-destructive' },
};

/** Status badge: ready=success, in-flight=brand (pulsing dot), failed=destructive. */
export function StatusBadge({ status, className }: { status: DocumentStatus; className?: string }) {
  const meta = STATUS_META[status] ?? STATUS_META.importing;
  const working = isWorkingStatus(status);
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-full border px-2 py-0.5 text-[11px] font-medium',
        meta.className,
        className
      )}
    >
      <span
        aria-hidden="true"
        className={cn(
          'h-1.5 w-1.5 rounded-full',
          working ? 'animate-pulse bg-brand-strong' : status === 'ready' ? 'bg-success' : 'bg-destructive'
        )}
      />
      {meta.label}
    </span>
  );
}

/* --------------------------- highlighting --------------------------- */

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Query terms worth highlighting (deduped, >1 char). */
export function queryTokens(query: string): string[] {
  return Array.from(new Set(query.trim().split(/\s+/).filter((t) => t.length > 1)));
}

/** Renders `text` with every query term marked in the brand accent. */
export function HighlightedText({ text, query }: { text: string; query: string }) {
  const raw = queryTokens(query).map(escapeRegExp);
  if (raw.length === 0) return <>{text}</>;
  let parts: string[] = [text];
  try {
    parts = text.split(new RegExp(`(${raw.join('|')})`, 'gi'));
  } catch {
    /* fall through with plain text */
  }
  return (
    <>
      {parts.map((part, i) =>
        i % 2 === 1 ? (
          <mark key={i} className="rounded-[2px] bg-brand px-0.5 text-brand-foreground">
            {part}
          </mark>
        ) : part ? (
          <Fragment key={i}>{part}</Fragment>
        ) : null
      )}
    </>
  );
}

/** Windowed snippet around the first query hit (for compact result rows). */
export function snippetFor(text: string, query: string, radius = 130): string {
  if (!text) return '';
  const tokens = queryTokens(query);
  if (tokens.length === 0) return text.slice(0, radius * 2).trimEnd();
  const lower = text.toLowerCase();
  let idx = -1;
  for (const t of tokens) {
    const i = lower.indexOf(t.toLowerCase());
    if (i !== -1 && (idx === -1 || i < idx)) idx = i;
  }
  if (idx === -1) return text.slice(0, radius * 2).trimEnd();
  const start = Math.max(0, idx - radius);
  const end = Math.min(text.length, idx + radius);
  return `${start > 0 ? '…' : ''}${text.slice(start, end).trim()}${end < text.length ? '…' : ''}`;
}

/* --------------------------- misc formatting ------------------------ */

/** Compact score: 2 decimals when ≥1 (BM25), 3 when smaller (cosine/RRF). */
export function formatScore(score: number): string {
  return score >= 1 ? score.toFixed(2) : score.toFixed(3);
}

/** Full, locale-aware timestamp for stat tables. */
export function formatDate(ts: number): string {
  return new Date(ts).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });
}

/* --------------------- Knowledge → Chat hand-off ------------------- */

/**
 * "Ask about this document": creates a fresh chat scoped to the document
 * (retrieval searches only it — see Chat.knowledgeDocIds), deposits a
 * prefilled composer draft referencing the document and navigates there.
 * The chat view consumes the draft (see pendingDraft in
 * lib/core/deep-link.ts) and puts the caret in the composer. Nothing is
 * sent automatically — the user reviews the draft first.
 */
export async function askAboutDocument(doc: { id: string; name: string }): Promise<void> {
  const { chatService } = await import('@/lib/services/chat-service');
  const { pendingDraft } = await import('@/lib/core/deep-link');
  const { router } = await import('@/lib/core/router');
  const chat = await chatService.createChat({ knowledgeDocIds: [doc.id] });
  pendingDraft.chatId = chat.id;
  pendingDraft.text = `About “${doc.name}” — `;
  router.navigate(`/app/chat/${chat.id}`);
  // Composer focus lands after the chat view mounts (same proven pattern
  // as the starred view's "Continue in chat").
  window.setTimeout(() => {
    window.dispatchEvent(new CustomEvent('pocketllm:focus-composer'));
  }, 350);
}
