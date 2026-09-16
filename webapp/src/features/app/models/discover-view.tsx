'use client';

/**
 * ModelDiscoverView — Hugging Face GGUF repository search.
 *
 * Queries the server-side proxy via the network gateway (so strict
 * offline / audit rules apply). Results are public metadata only —
 * installing is limited to the curated catalog, stated honestly.
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ArrowLeft,
  Download,
  ExternalLink,
  Heart,
  Info,
  Search,
  SearchX,
  TriangleAlert,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState, MetaPill, PageHeader, Section } from '@/features/app/shared/ui';
import { gateway } from '@/lib/core/net/network-gateway';
import { useAppStore } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';
import { formatNumber, formatRelativeTime } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';

interface HFRepo {
  id: string;
  author: string;
  likes: number;
  downloads: number;
  license: string;
  lastModified?: string;
  repoUrl: string;
}

const DEBOUNCE_MS = 400;

export function ModelDiscoverView() {
  const settings = useAppStore((s) => s.settings);
  const strictOffline = settings.privacy.strictOffline;

  const [query, setQuery] = useState('');
  const [results, setResults] = useState<HFRepo[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const requestIdRef = useRef(0);

  const runSearch = useCallback(async (q: string) => {
    const requestId = ++requestIdRef.current;
    setLoading(true);
    setError(null);
    try {
      const res = await gateway.request(
        'huggingface-search',
        `/api/hf?q=${encodeURIComponent(q)}`
      );
      const json = (await res.json().catch(() => null)) as {
        repositories?: HFRepo[];
        error?: string;
      } | null;
      if (!res.ok) {
        throw new Error(json?.error ?? `Search failed (HTTP ${res.status}).`);
      }
      if (requestId !== requestIdRef.current) return; // stale response
      setResults(json?.repositories ?? []);
    } catch (err) {
      if (requestId !== requestIdRef.current) return;
      setResults([]);
      const message =
        err instanceof Error ? err.message : 'Search failed. Try again.';
      setError(message);
      toast({
        title: 'Search failed',
        description: message,
        variant: 'destructive',
      });
    } finally {
      if (requestId === requestIdRef.current) setLoading(false);
    }
  }, []);

  // Debounced search as the user types.
  useEffect(() => {
    const q = query.trim();
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (q.length < 2) {
      setResults(null);
      setError(null);
      setLoading(false);
      return;
    }
    debounceRef.current = setTimeout(() => void runSearch(q), DEBOUNCE_MS);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [query, runSearch]);

  const onKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      const q = query.trim();
      if (q.length >= 2) {
        if (debounceRef.current) clearTimeout(debounceRef.current);
        void runSearch(q);
      }
    }
  };

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 pb-24 pt-6 sm:px-6">
        <Button
          variant="ghost"
          size="sm"
          className="-ml-2 mb-2 text-muted-foreground"
          onClick={() => router.navigate('/app/models')}
          aria-label="Back to Models"
        >
          <ArrowLeft aria-hidden />
          Models
        </Button>

        <PageHeader
          title="Discover models"
          description="Search public GGUF repositories on Hugging Face."
        />

        <div className="relative mb-6">
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
            aria-hidden
          />
          <Input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={onKeyDown}
            placeholder="Search repositories, e.g. llama gguf…"
            aria-label="Search Hugging Face for GGUF repositories"
            className="h-11 pl-9"
            autoFocus
            disabled={strictOffline}
          />
        </div>

        {strictOffline && (
          <Section className="mb-6">
            <div className="flex gap-3">
              <TriangleAlert
                className="mt-0.5 h-5 w-5 shrink-0 text-warning"
                aria-hidden
              />
              <div>
                <h2 className="text-[15px] font-semibold">
                  Strict Offline is enabled
                </h2>
                <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
                  Hugging Face search needs the network, so it is blocked by
                  your privacy policy. Turn Strict Offline off in Settings →
                  Privacy to search from here.
                </p>
              </div>
            </div>
          </Section>
        )}

        {/* Initial state — before any search */}
        {!strictOffline && results === null && !loading && !error && (
          <EmptyState
            icon={Search}
            title="Search Hugging Face"
            description="Type at least two characters. Results show public GGUF repositories with their metadata."
          />
        )}

        {/* Loading skeletons */}
        {loading && (
          <div className="space-y-3" role="status" aria-live="polite">
            <span className="sr-only">Searching Hugging Face…</span>
            <Skeleton className="h-24 w-full" />
            <Skeleton className="h-24 w-full" />
            <Skeleton className="h-24 w-full" />
          </div>
        )}

        {/* Error state */}
        {!loading && error && results !== null && (
          <EmptyState
            icon={TriangleAlert}
            title="Search failed"
            description={error}
            action={
              <Button
                variant="outline"
                onClick={() => void runSearch(query.trim())}
              >
                Try again
              </Button>
            }
          />
        )}

        {/* No results */}
        {!loading && !error && results !== null && results.length === 0 && (
          <EmptyState
            icon={SearchX}
            title="No GGUF repositories found"
            description={`Nothing matched “${query.trim()}”. Try a broader term like “llama” or “qwen”.`}
          />
        )}

        {/* Results */}
        {!loading && !error && results !== null && results.length > 0 && (
          <ul className="space-y-3">
            {results.map((repo) => (
              <li key={repo.id}>
                <article className="rounded-2xl border border-border bg-card p-4 transition-colors hover:border-brand-strong/60 sm:p-5">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0">
                      <h3 className="truncate text-sm font-semibold">
                        {repo.id}
                      </h3>
                      <div className="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-muted-foreground">
                        <span className="inline-flex items-center gap-1">
                          <Download className="h-3.5 w-3.5" aria-hidden />
                          {formatNumber(repo.downloads)} downloads
                        </span>
                        <span className="inline-flex items-center gap-1">
                          <Heart className="h-3.5 w-3.5" aria-hidden />
                          {formatNumber(repo.likes)}
                        </span>
                        {repo.lastModified && (
                          <span>
                            updated {formatRelativeTime(Date.parse(repo.lastModified) || 0)}
                          </span>
                        )}
                        <MetaPill tone="outline">{repo.license}</MetaPill>
                      </div>
                    </div>
                    <Button variant="outline" size="sm" asChild>
                      <a
                        href={repo.repoUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        aria-label={`Open ${repo.id} on Hugging Face (new tab)`}
                      >
                        Open repository
                        <ExternalLink aria-hidden />
                      </a>
                    </Button>
                  </div>
                </article>
              </li>
            ))}
          </ul>
        )}

        {/* Honest limitation note */}
        <Section className="mt-6">
          <div className="flex gap-3">
            <Info
              className="mt-0.5 h-5 w-5 shrink-0 text-muted-foreground"
              aria-hidden
            />
            <p className="text-[13px] leading-relaxed text-muted-foreground">
              Installing from arbitrary repositories is limited to the curated
              catalog — verify provenance and licensing yourself before using a
              model. PocketLLM never installs or executes anything you did not
              explicitly choose.
            </p>
          </div>
        </Section>
      </div>
    </div>
  );
}
