'use client';

/**
 * DocumentView — single document detail.
 *
 * Route: #/app/knowledge/<documentId>
 * Stats, retrieval controls (mode + chunk size + re-index), a chunk
 * browser with text filter, a scoped retrieval search (the RAG
 * debugging view) and the danger zone with honest delete semantics.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  ArrowLeft,
  Check,
  ChevronDown,
  Copy,
  FileX,
  Loader2,
  MessageSquareText,
  RefreshCw,
  Search,
  Trash2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState, MetaPill, Section } from '@/features/app/shared/ui';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import { router } from '@/lib/core/router';
import { documentService } from '@/lib/services/document-service';
import { settingsService } from '@/lib/services/settings-service';
import type { DocumentChunk, DocumentRecord, RetrievalMode } from '@/lib/types/domain';
import { cn, formatBytes, formatNumber } from '@/lib/utils';
import { DeleteDocumentDialog } from './delete-document-dialog';
import {
  DocumentIcon,
  HighlightedText,
  RETRIEVAL_MODES,
  StatusBadge,
  askAboutDocument,
  formatDate,
  isWorkingStatus,
  modeHint,
  typeLabel,
} from './helpers';
import { RetrievalTester } from './retrieval-tester';

const CHUNKS_PER_PAGE = 100;

export function DocumentView({ documentId }: { documentId: string }) {
  const [doc, setDoc] = useState<DocumentRecord | null>(null);
  const [chunks, setChunks] = useState<DocumentChunk[] | null>(null);
  const [notFound, setNotFound] = useState(false);

  const [chunkSearch, setChunkSearch] = useState('');
  const [visibleCount, setVisibleCount] = useState(CHUNKS_PER_PAGE);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());

  const [mode, setMode] = useState<RetrievalMode | null>(null);
  const [chunkSize, setChunkSize] = useState(() => String(settingsService.get().knowledge.chunkSize));
  const [reindexing, setReindexing] = useState(false);
  const [progressMessage, setProgressMessage] = useState<string | null>(null);

  const [deleteOpen, setDeleteOpen] = useState(false);
  const [copiedSha, setCopiedSha] = useState(false);

  const load = useCallback(async () => {
    try {
      const d = await documentService.get(documentId);
      if (!d) {
        setNotFound(true);
        return;
      }
      setNotFound(false);
      setDoc(d);
      setChunks(await documentService.chunksFor(documentId));
    } catch (err) {
      setNotFound(true);
      toast({
        title: 'Could not load document',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    }
  }, [documentId]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    // Payload may be absent (e.g. documentService.delete emits bare events).
    const unsub = bus.on('documents:changed', (payload) => {
      const changed = payload?.documentId;
      if (!changed || changed === documentId) void load();
    });
    return () => {
      unsub();
    };
  }, [load, documentId]);

  useEffect(() => {
    const unsub = documentService.onProgress((docId, _status, message) => {
      if (docId === documentId) setProgressMessage(message);
    });
    return () => {
      unsub();
    };
  }, [documentId]);

  // Reset pagination whenever the filter changes.
  useEffect(() => {
    setVisibleCount(CHUNKS_PER_PAGE);
  }, [chunkSearch]);

  const effectiveMode: RetrievalMode =
    mode ?? doc?.retrievalMode ?? settingsService.get().knowledge.defaultRetrievalMode;

  const filteredChunks = useMemo(() => {
    const q = chunkSearch.trim().toLowerCase();
    const all = chunks ?? [];
    if (!q) return all;
    return all.filter((c) => c.text.toLowerCase().includes(q));
  }, [chunks, chunkSearch]);

  const shownChunks = filteredChunks.slice(0, visibleCount);

  const toggleChunk = (id: string) => {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const copySha = async () => {
    if (!doc?.sha256) return;
    try {
      await navigator.clipboard.writeText(doc.sha256);
      setCopiedSha(true);
      toast({ title: 'SHA-256 copied', description: doc.sha256 });
      setTimeout(() => setCopiedSha(false), 2000);
    } catch {
      toast({
        title: 'Copy failed',
        description: 'The clipboard is unavailable in this context.',
        variant: 'destructive',
      });
    }
  };

  const handleReindex = async () => {
    if (!doc || reindexing) return;
    const size = Number.parseInt(chunkSize, 10);
    if (!Number.isFinite(size) || size < 100 || size > 8000) {
      toast({
        title: 'Invalid chunk size',
        description: 'Pick a chunk size between 100 and 8000 characters.',
        variant: 'destructive',
      });
      return;
    }
    setReindexing(true);
    setProgressMessage('Re-indexing…');
    try {
      await documentService.reindex(documentId, { chunkSize: size, retrievalMode: effectiveMode });
      const fresh = await documentService.chunksFor(documentId);
      toast({
        title: 'Re-index complete',
        description: `“${doc.name}” was re-chunked into ${fresh.length} chunks in ${effectiveMode} mode.`,
      });
    } catch (err) {
      toast({
        title: 'Re-index failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setReindexing(false);
      setProgressMessage(null);
    }
  };

  /* ---------------------------- states ---------------------------- */

  if (notFound) {
    return (
      <div className="flex-1 overflow-y-auto scrollbar-slim">
        <div className="mx-auto w-full max-w-3xl px-4 pb-24 pt-16 sm:px-6">
          <EmptyState
            icon={FileX}
            title="Document not found"
            description="It may have been deleted, or this link is stale. The knowledge list has everything currently stored in this browser."
            action={
              <Button variant="outline" onClick={() => router.navigate('/app/knowledge')}>
                <ArrowLeft className="h-4 w-4" />
                Back to Knowledge
              </Button>
            }
          />
        </div>
      </div>
    );
  }

  if (!doc || chunks === null) {
    return (
      <div className="flex-1 overflow-y-auto scrollbar-slim">
        <div
          className="mx-auto w-full max-w-4xl space-y-6 px-4 pb-24 pt-6 sm:px-6"
          aria-busy="true"
          aria-label="Loading document"
        >
          <Skeleton className="h-8 w-28" />
          <div className="space-y-3">
            <Skeleton className="h-8 w-2/3" />
            <Skeleton className="h-5 w-56" />
          </div>
          <Skeleton className="h-28 w-full rounded-2xl" />
          <Skeleton className="h-48 w-full rounded-2xl" />
          <Skeleton className="h-72 w-full rounded-2xl" />
        </div>
      </div>
    );
  }

  const working = isWorkingStatus(doc.status);

  const stats = [
    { label: 'Pages', value: doc.pageCount != null ? formatNumber(doc.pageCount) : '—' },
    { label: 'Chunks', value: formatNumber(doc.chunkCount) },
    { label: 'Source size', value: formatBytes(doc.sizeBytes) },
    { label: 'Index size', value: formatBytes(doc.indexSizeBytes) },
    { label: 'Imported', value: formatDate(doc.createdAt) },
    { label: 'Indexed', value: doc.indexedAt ? formatDate(doc.indexedAt) : '—' },
  ];

  /* ----------------------------- view ----------------------------- */

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 pb-24 pt-6 sm:px-6">
        <Button
          variant="ghost"
          size="sm"
          className="-ml-2 text-muted-foreground hover:text-foreground"
          onClick={() => router.navigate('/app/knowledge')}
        >
          <ArrowLeft className="h-4 w-4" />
          Knowledge
        </Button>

        {/* Header */}
        <header className="mt-3 flex flex-wrap items-start gap-3">
          <span className="mt-0.5 shrink-0 rounded-xl bg-muted p-2.5 text-muted-foreground">
            <DocumentIcon mimeType={doc.mimeType} name={doc.name} className="h-5 w-5" />
          </span>
          <div className="min-w-0 flex-1">
            <h1 className="break-words font-display text-xl font-semibold tracking-tight sm:text-2xl">
              {doc.name}
            </h1>
            <div className="mt-2 flex flex-wrap items-center gap-2">
              <StatusBadge status={doc.status} />
              <MetaPill tone="outline">{typeLabel(doc)}</MetaPill>
              <MetaPill tone="outline">{formatBytes(doc.sizeBytes)}</MetaPill>
              {doc.sha256 && (
                <MetaPill tone="outline">
                  <span className="font-mono" title={`sha256:${doc.sha256}`}>
                    {doc.sha256.slice(0, 12)}
                  </span>
                  <button
                    type="button"
                    onClick={copySha}
                    aria-label="Copy full SHA-256 checksum"
                    className="ml-0.5 rounded-sm text-muted-foreground transition-colors hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  >
                    {copiedSha ? (
                      <Check className="h-3 w-3 text-success" aria-hidden="true" />
                    ) : (
                      <Copy className="h-3 w-3" aria-hidden="true" />
                    )}
                  </button>
                </MetaPill>
              )}
            </div>
            {working && (
              <p className="mt-3 flex items-center gap-2 text-[13px] text-muted-foreground" role="status">
                <Loader2 className="h-4 w-4 animate-spin" aria-hidden="true" />
                {progressMessage ?? 'Working…'}
              </p>
            )}
            {doc.status === 'failed' && doc.error && (
              <p className="mt-3 flex items-start gap-2 rounded-xl border border-destructive/30 bg-destructive/5 p-3 text-[13px] leading-relaxed text-destructive">
                <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" aria-hidden="true" />
                {doc.error}
              </p>
            )}
          </div>
          {/* Primary cross-feature action: hand off to a fresh chat with a
              prefilled draft. Knowledge retrieval is automatic, so the draft
              states the intent and the user stays in control of sending. */}
          <div className="flex shrink-0 items-center gap-2 sm:mt-1">
            <Button
              size="sm"
              disabled={doc.status !== 'ready'}
              onClick={() =>
                void askAboutDocument(doc).catch((err: unknown) =>
                  toast({
                    title: 'Could not start chat',
                    description: err instanceof Error ? err.message : 'Try again.',
                    variant: 'destructive',
                  })
                )
              }
              className="gap-1.5 rounded-xl border-brand/40 bg-brand-soft font-medium text-foreground shadow-sm transition-all hover:-translate-y-px hover:border-brand-strong hover:shadow-md disabled:translate-y-0 disabled:shadow-none dark:bg-brand/15"
              title={
                doc.status === 'ready'
                  ? 'Start a new chat about this document'
                  : 'Available once indexing finishes'
              }
            >
              <MessageSquareText className="h-4 w-4 text-brand-strong" aria-hidden="true" />
              Ask about this document
            </Button>
          </div>
        </header>

        {/* Stats */}
        <Section title="Stats" className="mt-6">
          <dl className="grid grid-cols-2 gap-x-4 gap-y-4 sm:grid-cols-3">
            {stats.map((s) => (
              <div key={s.label}>
                <dt className="text-[11px] uppercase tracking-wide text-muted-foreground">{s.label}</dt>
                <dd className="mt-1 text-sm font-medium tabular-nums">{s.value}</dd>
              </div>
            ))}
          </dl>
        </Section>

        {/* Retrieval */}
        <Section
          title="Retrieval"
          description="How chat searches this document. Changes to mode and chunk size apply on re-index."
          className="mt-6"
        >
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <Label htmlFor="retrieval-mode">Mode</Label>
              <Select value={effectiveMode} onValueChange={(v) => setMode(v as RetrievalMode)}>
                <SelectTrigger id="retrieval-mode" className="mt-1.5 w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {RETRIEVAL_MODES.map((m) => (
                    <SelectItem key={m.value} value={m.value}>
                      {m.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <p className="mt-1.5 text-[11px] leading-relaxed text-muted-foreground">
                {modeHint(effectiveMode)}
              </p>
            </div>
            <div>
              <Label htmlFor="chunk-size">Chunk size (characters)</Label>
              <Input
                id="chunk-size"
                type="number"
                min={100}
                max={8000}
                step={50}
                value={chunkSize}
                onChange={(e) => setChunkSize(e.target.value)}
                className="mt-1.5 w-full"
                disabled={reindexing}
                aria-describedby="chunk-size-hint"
              />
              <p id="chunk-size-hint" className="mt-1.5 text-[11px] leading-relaxed text-muted-foreground">
                Smaller chunks give finer citations; larger chunks keep more context per hit.
              </p>
            </div>
          </div>
          <div className="mt-4 flex flex-wrap items-center gap-3">
            <Button onClick={() => void handleReindex()} disabled={reindexing || doc.status !== 'ready'}>
              <RefreshCw className={cn('h-4 w-4', reindexing && 'animate-spin')} />
              {reindexing ? 'Re-indexing…' : 'Re-index'}
            </Button>
            {reindexing && progressMessage && (
              <span className="text-xs text-muted-foreground" role="status">
                {progressMessage}
              </span>
            )}
            {doc.status !== 'ready' && !reindexing && (
              <span className="text-xs text-muted-foreground">
                Available once the document is ready.
              </span>
            )}
          </div>
        </Section>

        {/* Scoped retrieval search — the RAG debugging view */}
        {doc.status === 'ready' && chunks.length > 0 && (
          <Section className="mt-6">
            <RetrievalTester
              documentId={documentId}
              title="Search this document"
              description="Ranked retrieval scoped to this document — the same local pipeline chat uses. Your RAG debugging view."
            />
          </Section>
        )}

        {/* Chunks browser */}
        <Section
          title="Chunks"
          description="Structure-aware chunks with page tracking. The filter matches chunk text."
          className="mt-6"
        >
          <div className="relative">
            <Search
              className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/70"
              aria-hidden="true"
            />
            <Input
              value={chunkSearch}
              onChange={(e) => setChunkSearch(e.target.value)}
              placeholder="Filter chunks by text…"
              className="pl-9"
              aria-label="Filter chunks by text"
            />
          </div>
          <p className="mt-2 text-[11px] text-muted-foreground" role="status">
            {chunkSearch.trim()
              ? `${formatNumber(filteredChunks.length)} of ${formatNumber(chunks.length)} chunks match`
              : `${formatNumber(chunks.length)} chunks`}
          </p>

          {chunks.length === 0 ? (
            <p className="mt-3 rounded-xl border border-dashed border-border px-4 py-8 text-center text-[13px] text-muted-foreground">
              No chunks yet — the document needs to finish indexing first.
            </p>
          ) : filteredChunks.length === 0 ? (
            <p className="mt-3 rounded-xl border border-dashed border-border px-4 py-8 text-center text-[13px] text-muted-foreground">
              No chunks contain “{chunkSearch.trim()}”.
            </p>
          ) : (
            <>
              <ul
                className="mt-3 max-h-[520px] space-y-2 overflow-y-auto scrollbar-slim pr-1"
                aria-label="Document chunks"
              >
                {shownChunks.map((chunk) => {
                  const isOpen = expanded.has(chunk.id);
                  return (
                    <li key={chunk.id} className="rounded-xl border border-border bg-card p-3">
                      <div className="flex flex-wrap items-center gap-2">
                        <MetaPill tone="outline">#{chunk.seq + 1}</MetaPill>
                        {chunk.page != null && <MetaPill tone="outline">p. {chunk.page}</MetaPill>}
                        <span className="text-[11px] tabular-nums text-muted-foreground">
                          {formatNumber(chunk.tokens)} tokens
                        </span>
                        <button
                          type="button"
                          onClick={() => toggleChunk(chunk.id)}
                          aria-expanded={isOpen}
                          className="ml-auto flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[11px] text-muted-foreground transition-colors hover:bg-muted hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                        >
                          {isOpen ? 'Collapse' : 'Expand'}
                          <ChevronDown
                            className={cn('h-3.5 w-3.5 transition-transform', isOpen && 'rotate-180')}
                            aria-hidden="true"
                          />
                        </button>
                      </div>
                      <p
                        className={cn(
                          'mt-2 break-words whitespace-pre-wrap text-[13px] leading-relaxed',
                          !isOpen && 'line-clamp-4'
                        )}
                      >
                        <HighlightedText text={chunk.text} query={chunkSearch} />
                      </p>
                    </li>
                  );
                })}
              </ul>
              {visibleCount < filteredChunks.length && (
                <div className="mt-3 flex justify-center">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setVisibleCount((c) => c + CHUNKS_PER_PAGE)}
                  >
                    Load more — {formatNumber(filteredChunks.length - visibleCount)} remaining
                  </Button>
                </div>
              )}
            </>
          )}
        </Section>

        {/* Danger zone */}
        <Section title="Danger zone" className="mt-6 border-destructive/30">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="text-sm font-medium">Delete this document</p>
              <p className="mt-1 max-w-md text-[13px] leading-relaxed text-muted-foreground">
                Deletes source + chunks + embeddings. Existing chat citations keep tombstone metadata —
                the name and excerpt stay visible, the text becomes unretrievable.
              </p>
            </div>
            <Button variant="destructive" onClick={() => setDeleteOpen(true)}>
              <Trash2 className="h-4 w-4" />
              Delete document
            </Button>
          </div>
        </Section>
      </div>

      <DeleteDocumentDialog
        doc={doc}
        open={deleteOpen}
        onOpenChange={setDeleteOpen}
        onDeleted={() => router.navigate('/app/knowledge')}
      />
    </div>
  );
}
