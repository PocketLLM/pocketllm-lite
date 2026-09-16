'use client';

/**
 * MemoriesView — what PocketLLM remembers about you.
 *
 * Route: #/app/memories
 * A manager for the local memory store: stats, filters, search, and
 * full edit/pin/disable/delete control over every remembered fact.
 * Supersession chains are surfaced honestly. A privacy section
 * explains exactly how memory works and where the data lives.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Brain, Check, Plus, Search } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import {
  EmptyState,
  ListToolbar,
  PageHeader,
  Section,
} from '@/features/app/shared/ui';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import { deepLink } from '@/lib/core/deep-link';
import { useDeepLink } from '@/lib/core/use-deep-link';
import { memoryService } from '@/lib/services/memory-service';
import type { Memory } from '@/lib/types/domain';
import { cn, formatNumber } from '@/lib/utils';
import { MemoryCard } from './memory-card';
import { MemoryDialog } from './memory-dialog';

type MemoryFilter = 'all' | 'pinned' | 'disabled' | 'superseded';

const FILTERS: { id: MemoryFilter; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'pinned', label: 'Pinned' },
  { id: 'disabled', label: 'Disabled' },
  { id: 'superseded', label: 'Superseded' },
];

export function MemoriesView() {
  const [memories, setMemories] = useState<Memory[] | null>(null);
  const [filter, setFilter] = useState<MemoryFilter>('all');
  const [query, setQuery] = useState('');
  const [searchResults, setSearchResults] = useState<Memory[] | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Memory | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Memory | null>(null);
  const [deleting, setDeleting] = useState(false);

  const refresh = useCallback(async () => {
    try {
      setMemories(await memoryService.list());
    } catch (err) {
      setMemories([]);
      toast({
        title: 'Could not load memories',
        description:
          err instanceof Error
            ? err.message
            : 'Local storage is unavailable in this session.',
        variant: 'destructive',
      });
    }
  }, []);

  useEffect(() => {
    void refresh();
    const unsub = bus.on('memories:changed', () => void refresh());
    return () => {
      unsub();
    };
  }, [refresh]);

  // Deep link from the command palette: open this memory's editor
  // once the list has loaded (cross-route navigation).
  const consumedDeepLink = useRef(false);
  useEffect(() => {
    if (consumedDeepLink.current || !memories) return;
    const request = deepLink.take('memory');
    if (!request) {
      consumedDeepLink.current = true;
      return;
    }
    const target = memories.find((m) => m.id === request.id);
    if (target) {
      setEditTarget(target);
      setDialogOpen(true);
    }
    consumedDeepLink.current = true;
  }, [memories]);

  // Live deep links: palette selections while this view is already open.
  useDeepLink<Memory>(
    'memory',
    (id) => (memories ?? []).find((m) => m.id === id),
    (m) => openEdit(m)
  );

  // Debounced search through the service (matches fact + subject).
  useEffect(() => {
    const q = query.trim();
    if (!q) {
      setSearchResults(null);
      return;
    }
    const timer = setTimeout(() => {
      memoryService
        .search(q)
        .then(setSearchResults)
        .catch(() => setSearchResults([]));
    }, 250);
    return () => clearTimeout(timer);
  }, [query]);

  const stats = useMemo(() => {
    const all = memories ?? [];
    return {
      total: all.length,
      active: all.filter((m) => m.enabled && !m.supersededBy).length,
      pinned: all.filter((m) => m.pinned).length,
      superseded: all.filter((m) => m.supersededBy).length,
    };
  }, [memories]);

  const counts = useMemo<Record<MemoryFilter, number>>(
    () => ({
      all: stats.total,
      pinned: stats.pinned,
      disabled: (memories ?? []).filter((m) => !m.enabled).length,
      superseded: stats.superseded,
    }),
    [memories, stats]
  );

  const supersederFacts = useMemo(() => {
    const byId = new Map((memories ?? []).map((m) => [m.id, m.fact]));
    const lookup = new Map<string, string>();
    for (const m of memories ?? []) {
      if (m.supersededBy) {
        const fact = byId.get(m.supersededBy);
        if (fact) lookup.set(m.id, fact);
      }
    }
    return lookup;
  }, [memories]);

  const visible = useMemo(() => {
    const base = searchResults ?? memories ?? [];
    switch (filter) {
      case 'pinned':
        return base.filter((m) => m.pinned);
      case 'disabled':
        return base.filter((m) => !m.enabled);
      case 'superseded':
        return base.filter((m) => m.supersededBy);
      default:
        return base;
    }
  }, [memories, searchResults, filter]);

  const openAdd = useCallback(() => {
    setEditTarget(null);
    setDialogOpen(true);
  }, []);

  const openEdit = useCallback((memory: Memory) => {
    setEditTarget(memory);
    setDialogOpen(true);
  }, []);

  const handleTogglePin = useCallback(async (memory: Memory) => {
    try {
      await memoryService.update(memory.id, { pinned: !memory.pinned });
    } catch (err) {
      toast({
        title: 'Could not update memory',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    }
  }, []);

  const handleToggleEnabled = useCallback(async (memory: Memory) => {
    try {
      await memoryService.update(memory.id, { enabled: !memory.enabled });
    } catch (err) {
      toast({
        title: 'Could not update memory',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    }
  }, []);

  const handleDelete = useCallback(async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await memoryService.delete(deleteTarget.id);
      toast({ title: 'Memory deleted' });
      setDeleteTarget(null);
    } catch (err) {
      toast({
        title: 'Could not delete memory',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setDeleting(false);
    }
  }, [deleteTarget]);

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 pb-24 pt-6 sm:px-6 sm:pt-8">
        <PageHeader
          title="Memory"
          description="What PocketLLM remembers about you. Everything is editable and stays on this device."
          actions={
            <Button onClick={openAdd}>
              <Plus aria-hidden />
              Add memory
            </Button>
          }
        />

        {memories === null ? (
          <div className="space-y-3" aria-hidden>
            {Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="h-24 rounded-xl" />
            ))}
          </div>
        ) : memories.length === 0 ? (
          <div className="mt-4">
            <EmptyState
              icon={Brain}
              title="No memories yet"
              description="Add a fact manually, or let PocketLLM extract memories from your chats — automatic extraction is opt-in in Settings → Memory. Everything stays on this device."
              action={
                <Button onClick={openAdd}>
                  <Plus aria-hidden />
                  Add memory
                </Button>
              }
            />
          </div>
        ) : (
          <>
            <StatsStrip stats={stats} />

            <div className="pt-6">
              <ListToolbar>
                <div className="relative w-full sm:w-64">
                  <Search
                    className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
                    aria-hidden
                  />
                  <Input
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="Search memories…"
                    aria-label="Search memories"
                    className="w-full pl-8"
                  />
                </div>
                <div
                  className="flex flex-wrap items-center gap-1.5"
                  role="group"
                  aria-label="Filter memories"
                >
                  {FILTERS.map((f) => (
                    <button
                      key={f.id}
                      type="button"
                      onClick={() => setFilter(f.id)}
                      aria-pressed={filter === f.id}
                      className={cn(
                        'rounded-full border px-3 py-1 text-xs transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
                        filter === f.id
                          ? 'border-transparent bg-brand font-medium text-brand-foreground'
                          : 'border-border text-muted-foreground hover:text-foreground'
                      )}
                    >
                      {f.label}
                      <span className="ml-1 tabular-nums opacity-70">
                        {counts[f.id]}
                      </span>
                    </button>
                  ))}
                </div>
              </ListToolbar>
            </div>

            {visible.length === 0 ? (
              <div className="rounded-xl border border-dashed border-border px-6 py-10 text-center">
                <p className="text-sm text-muted-foreground">
                  {query.trim()
                    ? `No memories match “${query.trim()}”.`
                    : 'No memories in this view.'}
                </p>
                {(query.trim() || filter !== 'all') && (
                  <Button
                    variant="outline"
                    size="sm"
                    className="mt-3"
                    onClick={() => {
                      setQuery('');
                      setFilter('all');
                    }}
                  >
                    Clear search and filters
                  </Button>
                )}
              </div>
            ) : (
              <ul className="space-y-3">
                {visible.map((memory) => (
                  <MemoryCard
                    key={memory.id}
                    memory={memory}
                    supersederFact={supersederFacts.get(memory.id)}
                    onTogglePin={(m) => void handleTogglePin(m)}
                    onToggleEnabled={(m) => void handleToggleEnabled(m)}
                    onEdit={openEdit}
                    onDelete={setDeleteTarget}
                  />
                ))}
              </ul>
            )}
          </>
        )}

        <Section
          title="How memory works"
          description="Memories are short facts PocketLLM can weave into the system prompt of a chat. You are always in control:"
          className="mt-10"
        >
          <ul className="grid gap-3 sm:grid-cols-3">
            {[
              'Automatic extraction is opt-in — enable or disable it in Settings → Memory.',
              'Each chat has its own memory toggle, so memories only apply where you allow them.',
              'Nothing leaves this device — memories live in this browser and are composed into prompts locally.',
            ].map((text) => (
              <li
                key={text}
                className="flex gap-2.5 text-[13px] leading-relaxed text-muted-foreground"
              >
                <Check
                  className="mt-0.5 h-4 w-4 shrink-0 text-success"
                  aria-hidden
                />
                <span>{text}</span>
              </li>
            ))}
          </ul>
        </Section>
      </div>

      <MemoryDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        memory={dialogOpen ? editTarget : null}
      />

      <AlertDialog
        open={!!deleteTarget}
        onOpenChange={(open) => {
          if (!open) setDeleteTarget(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete memory?</AlertDialogTitle>
            <AlertDialogDescription>
              “{deleteTarget?.fact}” will be removed permanently. Chats that
              already used it keep their messages — only future prompts lose
              this fact.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={deleting}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-white hover:bg-destructive/90 dark:bg-destructive/60"
              disabled={deleting}
              onClick={(e) => {
                // Keep the dialog open until the delete settles.
                e.preventDefault();
                void handleDelete();
              }}
            >
              Delete memory
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

function StatsStrip({
  stats,
}: {
  stats: { total: number; active: number; pinned: number; superseded: number };
}) {
  const cells = [
    { label: 'Total', value: formatNumber(stats.total) },
    { label: 'Active', value: formatNumber(stats.active) },
    { label: 'Pinned', value: formatNumber(stats.pinned) },
    { label: 'Superseded', value: formatNumber(stats.superseded) },
  ];
  return (
    <dl>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {cells.map((cell) => (
          <div
            key={cell.label}
            className="rounded-xl border border-border bg-card px-3.5 py-3"
          >
            <dt className="text-[11px] uppercase tracking-wide text-muted-foreground">
              {cell.label}
            </dt>
            <dd className="mt-1 font-display text-lg font-semibold tabular-nums">
              {cell.value}
            </dd>
          </div>
        ))}
      </div>
    </dl>
  );
}
