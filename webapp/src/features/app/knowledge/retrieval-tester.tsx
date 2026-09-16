'use client';

/**
 * RetrievalTester — live RAG search preview.
 *
 * Runs `retrievalService.retrieve` exactly like the chat pipeline does
 * (same mode + topK defaults from settings) and renders the ranked
 * chunks with document, page, score and a highlighted snippet.
 * When `documentId` is provided the search is scoped to that single
 * document — the RAG debugging view.
 */
import { useEffect, useRef, useState } from 'react';
import { Loader2, Search, SearchX } from 'lucide-react';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { MetaPill } from '@/features/app/shared/ui';
import { toast } from '@/hooks/use-toast';
import { router } from '@/lib/core/router';
import { retrievalService, type RetrievedChunk } from '@/lib/services/retrieval-service';
import { settingsService } from '@/lib/services/settings-service';
import type { RetrievalMode } from '@/lib/types/domain';
import { RETRIEVAL_MODES, HighlightedText, formatScore, modeHint, snippetFor } from './helpers';

export function RetrievalTester({
  documentId,
  title = 'Search preview',
  description,
}: {
  /** Scope retrieval to a single document (debug view). */
  documentId?: string;
  title?: string;
  description?: string;
}) {
  const [query, setQuery] = useState('');
  const [mode, setMode] = useState<RetrievalMode>(
    () => settingsService.get().knowledge.defaultRetrievalMode
  );
  const [results, setResults] = useState<RetrievedChunk[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);
  const runToken = useRef(0);

  const topK = settingsService.get().knowledge.topK;
  const trimmed = query.trim();

  useEffect(() => {
    if (trimmed.length < 2) {
      setResults([]);
      setSearched(false);
      setLoading(false);
      return;
    }
    setLoading(true);
    const run = ++runToken.current;
    const timer = setTimeout(async () => {
      try {
        const res = await retrievalService.retrieve(trimmed, {
          mode,
          documentIds: documentId ? [documentId] : undefined,
          topK,
        });
        if (run !== runToken.current) return; // stale response
        setResults(res);
        setSearched(true);
      } catch (err) {
        if (run !== runToken.current) return;
        setResults([]);
        setSearched(true);
        toast({
          title: 'Retrieval failed',
          description: err instanceof Error ? err.message : 'The local index could not be queried.',
          variant: 'destructive',
        });
      } finally {
        if (run === runToken.current) setLoading(false);
      }
    }, 300);
    return () => clearTimeout(timer);
  }, [trimmed, mode, documentId, topK]);

  const fallbackDescription = documentId
    ? 'Ranked exactly like chat retrieval, scoped to this document — your RAG debugging view.'
    : 'Test how chat retrieves from your documents — runs entirely in this browser.';

  return (
    <section aria-label={title}>
      <div className="mb-3 flex flex-wrap items-end justify-between gap-2">
        <div className="min-w-0">
          <h2 className="text-[15px] font-semibold">{title}</h2>
          <p className="mt-0.5 max-w-lg text-[13px] text-muted-foreground">
            {description ?? fallbackDescription}
          </p>
        </div>
        <div className="shrink-0">
          <label className="sr-only" htmlFor={`tester-mode-${documentId ?? 'all'}`}>
            Retrieval mode
          </label>
          <Select value={mode} onValueChange={(v) => setMode(v as RetrievalMode)}>
            <SelectTrigger
              id={`tester-mode-${documentId ?? 'all'}`}
              size="sm"
              className="w-[140px]"
            >
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
        </div>
      </div>

      <div className="relative">
        <Search
          className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/70"
          aria-hidden="true"
        />
        <Input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={documentId ? 'Search this document…' : 'Search all documents…'}
          className="pl-9 pr-9"
          aria-label={documentId ? 'Search this document' : 'Search all documents'}
        />
        {loading && (
          <Loader2
            className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-muted-foreground"
            aria-hidden="true"
          />
        )}
      </div>
      <p className="mt-1.5 text-[11px] text-muted-foreground">{modeHint(mode)}</p>

      {(loading || searched) && (
        <p className="mt-3 text-[11px] text-muted-foreground" role="status" aria-live="polite">
          {loading
            ? 'Searching…'
            : `${results.length} chunk${results.length === 1 ? '' : 's'} matched (top ${topK})`}
        </p>
      )}

      {results.length > 0 && (
        <ol className="mt-2 max-h-[420px] space-y-2 overflow-y-auto scrollbar-slim pr-1">
          {results.map((chunk) => (
            <li key={chunk.id} className="rounded-xl border border-border bg-card p-3">
              <div className="flex flex-wrap items-center gap-2 text-[11px] text-muted-foreground">
                {documentId ? (
                  <span className="font-medium text-foreground">Chunk #{chunk.seq + 1}</span>
                ) : (
                  <button
                    type="button"
                    className="max-w-[220px] truncate font-medium text-foreground underline-offset-2 transition-colors hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background"
                    onClick={() => router.navigate(`/app/knowledge/${chunk.documentId}`)}
                    aria-label={`Open ${chunk.documentName}`}
                  >
                    {chunk.documentName}
                  </button>
                )}
                <MetaPill tone="outline">#{chunk.seq + 1}</MetaPill>
                {chunk.page != null && <MetaPill tone="outline">p. {chunk.page}</MetaPill>}
                <span className="ml-auto font-mono text-[10px] tabular-nums">
                  score {formatScore(chunk.score)}
                </span>
              </div>
              <p className="mt-1.5 break-words text-[13px] leading-relaxed text-foreground/90">
                <HighlightedText text={snippetFor(chunk.text, query)} query={query} />
              </p>
            </li>
          ))}
        </ol>
      )}

      {searched && !loading && results.length === 0 && (
        <p className="mt-3 flex items-center gap-2 rounded-xl border border-dashed border-border px-3 py-4 text-[13px] text-muted-foreground">
          <SearchX className="h-4 w-4 shrink-0" aria-hidden="true" />
          No chunks matched “{trimmed}”.
        </p>
      )}
    </section>
  );
}
