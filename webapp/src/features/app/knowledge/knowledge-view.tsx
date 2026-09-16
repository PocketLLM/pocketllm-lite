'use client';

/**
 * KnowledgeView — the document knowledge base.
 *
 * Route: #/app/knowledge
 * Import (drag-drop + picker, live pipeline progress), a live RAG
 * search preview that runs exactly like chat retrieval, a document
 * grid and a storage stats strip. Everything is local: OPFS source
 * files, IndexedDB records + chunks, in-browser retrieval.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { BookOpen, Upload } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState, PageHeader } from '@/features/app/shared/ui';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import { router } from '@/lib/core/router';
import { documentService } from '@/lib/services/document-service';
import type { DocumentRecord } from '@/lib/types/domain';
import { formatBytes, formatNumber } from '@/lib/utils';
import { DeleteDocumentDialog } from './delete-document-dialog';
import { DocumentCard } from './document-card';
import { ImportZone } from './import-zone';
import { RetrievalTester } from './retrieval-tester';
import { askAboutDocument, isWorkingStatus } from './helpers';

const SUPPORTED_PATTERN = /\.(pdf|txt|md|markdown|csv|tsv)$/i;

export function KnowledgeView() {
  const [docs, setDocs] = useState<DocumentRecord[] | null>(null);
  /** Live pipeline messages keyed by documentId. */
  const [progress, setProgress] = useState<Record<string, string>>({});
  const [deleteTarget, setDeleteTarget] = useState<DocumentRecord | null>(null);
  const [reindexingIds, setReindexingIds] = useState<Set<string>>(new Set());
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const refresh = useCallback(async () => {
    try {
      const list = await documentService.list();
      setDocs(list);
      // Prune progress messages that no longer belong to in-flight imports.
      setProgress((prev) => {
        const next: Record<string, string> = {};
        for (const d of list) {
          if (isWorkingStatus(d.status) && prev[d.id]) next[d.id] = prev[d.id];
        }
        return next;
      });
    } catch (err) {
      setDocs([]);
      toast({
        title: 'Could not load documents',
        description: err instanceof Error ? err.message : 'Local storage is unavailable in this session.',
        variant: 'destructive',
      });
    }
  }, []);

  useEffect(() => {
    void refresh();
    const unsub = bus.on('documents:changed', () => void refresh());
    return () => {
      unsub();
    };
  }, [refresh]);

  useEffect(() => {
    const unsub = documentService.onProgress((docId, _status, message) => {
      setProgress((prev) => ({ ...prev, [docId]: message }));
    });
    return () => {
      unsub();
    };
  }, []);

  const importing = useMemo(() => (docs ?? []).some((d) => isWorkingStatus(d.status)), [docs]);

  const importFiles = useCallback(async (files: File[]) => {
    for (const file of files) {
      if (!SUPPORTED_PATTERN.test(file.name)) {
        toast({
          title: 'Unsupported file type',
          description: `“${file.name}” was skipped — supported formats are PDF, TXT, MD, CSV and TSV.`,
          variant: 'destructive',
        });
        continue;
      }
      try {
        const doc = await documentService.import(file);
        toast({
          title: 'Document ready',
          description: `“${doc.name}” — ${doc.chunkCount} chunks indexed locally.`,
        });
      } catch (err) {
        // The service throws honest, user-facing reasons (image-only PDF,
        // duplicate, too large, empty file…).
        toast({
          title: `Import failed: ${file.name}`,
          description: err instanceof Error ? err.message : 'Unknown error.',
          variant: 'destructive',
        });
      }
    }
  }, []);

  const handleReindex = useCallback(async (doc: DocumentRecord) => {
    setReindexingIds((prev) => new Set(prev).add(doc.id));
    try {
      await documentService.reindex(doc.id);
      toast({
        title: 'Re-indexed',
        description: `“${doc.name}” was re-chunked from its stored source.`,
      });
    } catch (err) {
      toast({
        title: 'Re-index failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setReindexingIds((prev) => {
        const next = new Set(prev);
        next.delete(doc.id);
        return next;
      });
    }
  }, []);

  const handleDismissFailed = useCallback(async (doc: DocumentRecord) => {
    try {
      await documentService.delete(doc.id);
      toast({
        title: 'Failed import dismissed',
        description: `“${doc.name}” was removed from the list.`,
      });
    } catch (err) {
      toast({
        title: 'Could not remove',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    }
  }, []);

  const readyDocs = useMemo(() => (docs ?? []).filter((d) => d.status === 'ready'), [docs]);

  const stats = useMemo(() => {
    const active = (docs ?? []).filter((d) => d.status !== 'failed');
    return {
      documents: active.length,
      chunks: active.reduce((s, d) => s + d.chunkCount, 0),
      sourceBytes: active.reduce((s, d) => s + d.sizeBytes, 0),
      indexBytes: active.reduce((s, d) => s + d.indexSizeBytes, 0),
    };
  }, [docs]);

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-5xl px-4 pb-24 pt-6 sm:px-6 sm:pt-8">
        <PageHeader
          title="Knowledge"
          description="Documents stay in this browser. Chat searches them locally."
          actions={
            <Button onClick={() => fileInputRef.current?.click()}>
              <Upload className="h-4 w-4" />
              Import documents
            </Button>
          }
        />

        <ImportZone onFiles={(files) => void importFiles(files)} inputRef={fileInputRef} busy={importing} />

        {docs === null ? (
          <div className="mt-6 grid gap-3 sm:grid-cols-2 xl:grid-cols-3" aria-hidden="true">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton key={i} className="h-[172px] rounded-xl" />
            ))}
          </div>
        ) : docs.length === 0 ? (
          <div className="mt-8">
            <EmptyState
              icon={BookOpen}
              title="No documents yet"
              description="Import PDFs, markdown, text or CSV files — everything is stored and searched in this browser. PDFs must contain real text; image-only scans can't be read without OCR."
              action={
                <Button onClick={() => fileInputRef.current?.click()}>
                  <Upload className="h-4 w-4" />
                  Import documents
                </Button>
              }
            />
          </div>
        ) : (
          <>
            <StatsStrip className="mt-6" stats={stats} />

            {readyDocs.length > 0 && (
              <div className="mt-8">
                <RetrievalTester />
              </div>
            )}

            <section className="mt-8" aria-labelledby="documents-heading">
              <div className="mb-3 flex items-center justify-between">
                <h2 id="documents-heading" className="text-sm font-semibold text-muted-foreground">
                  Documents
                </h2>
                <span className="text-[11px] text-muted-foreground">
                  {docs.length} total
                </span>
              </div>
              <ul className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
                {docs.map((doc) => (
                  <li key={doc.id} className="h-full">
                    <DocumentCard
                      doc={doc}
                      progressMessage={progress[doc.id]}
                      reindexing={reindexingIds.has(doc.id)}
                      onOpen={(id) => router.navigate(`/app/knowledge/${id}`)}
                      onReindex={(d) => void handleReindex(d)}
                      onDelete={(d) => setDeleteTarget(d)}
                      onDismiss={(d) => void handleDismissFailed(d)}
                      onAsk={(d) => void askAboutDocument(d)}
                    />
                  </li>
                ))}
              </ul>
            </section>
          </>
        )}
      </div>

      <DeleteDocumentDialog
        doc={deleteTarget}
        open={!!deleteTarget}
        onOpenChange={(open) => {
          if (!open) setDeleteTarget(null);
        }}
      />
    </div>
  );
}

function StatsStrip({
  stats,
  className,
}: {
  stats: { documents: number; chunks: number; sourceBytes: number; indexBytes: number };
  className?: string;
}) {
  const cells = [
    { label: 'Documents', value: formatNumber(stats.documents) },
    { label: 'Chunks', value: formatNumber(stats.chunks) },
    { label: 'Source size', value: formatBytes(stats.sourceBytes) },
    { label: 'Index size', value: formatBytes(stats.indexBytes) },
  ];
  return (
    <dl className={className}>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {cells.map((cell) => (
          <div key={cell.label} className="rounded-xl border border-border bg-card px-3.5 py-3">
            <dt className="text-[11px] uppercase tracking-wide text-muted-foreground">{cell.label}</dt>
            <dd className="mt-1 font-display text-lg font-semibold tabular-nums">{cell.value}</dd>
          </div>
        ))}
      </div>
    </dl>
  );
}
