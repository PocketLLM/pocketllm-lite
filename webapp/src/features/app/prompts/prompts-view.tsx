'use client';

/**
 * PromptsView — the reusable prompt library.
 *
 * Route: #/app/prompts
 * Search + category chips, a grid of prompt cards with "Use in chat"
 * (creates a chat, prefills the composer draft and navigates), copy
 * with feedback, edit and delete with confirmation.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import { MessageSquareText, Plus, Search } from 'lucide-react';
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
import { EmptyState, ListToolbar, PageHeader } from '@/features/app/shared/ui';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import { promptRepo } from '@/lib/core/db/repositories';
import { deepLink } from '@/lib/core/deep-link';
import { useDeepLink } from '@/lib/core/use-deep-link';
import { cn } from '@/lib/utils';
import type { Prompt } from '@/lib/types/domain';
import { PromptCard } from './prompt-card';
import { PromptDialog } from './prompt-dialog';

export function PromptsView() {
  const [prompts, setPrompts] = useState<Prompt[] | null>(null);
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState<string>('all');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Prompt | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Prompt | null>(null);
  const [deleting, setDeleting] = useState(false);

  const refresh = useCallback(async () => {
    try {
      const all = await promptRepo.getAll();
      const sorted = all.sort((a, b) => b.updatedAt - a.updatedAt);
      setPrompts(sorted);
      // Deep link from the command palette: open this prompt's editor.
      const request = deepLink.take('prompt');
      const target = request ? sorted.find((p) => p.id === request.id) : undefined;
      if (target) {
        setEditTarget(target);
        setDialogOpen(true);
      }
    } catch (err) {
      setPrompts([]);
      toast({
        title: 'Could not load prompts',
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
    const unsub = bus.on('prompts:changed', () => void refresh());
    return () => {
      unsub();
    };
  }, [refresh]);

  const categories = useMemo(() => {
    const set = new Set<string>();
    for (const p of prompts ?? []) {
      if (p.category) set.add(p.category);
    }
    return [...set].sort((a, b) => a.localeCompare(b));
  }, [prompts]);

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return (prompts ?? []).filter((p) => {
      if (category !== 'all' && p.category !== category) return false;
      if (!q) return true;
      return (
        p.title.toLowerCase().includes(q) ||
        p.body.toLowerCase().includes(q) ||
        (p.category ?? '').toLowerCase().includes(q)
      );
    });
  }, [prompts, query, category]);

  const openNew = useCallback(() => {
    setEditTarget(null);
    setDialogOpen(true);
  }, []);

  const openEdit = useCallback((prompt: Prompt) => {
    setEditTarget(prompt);
    setDialogOpen(true);
  }, []);

  // Live deep links: palette selections while this view is already open.
  useDeepLink<Prompt>(
    'prompt',
    (id) => (prompts ?? []).find((p) => p.id === id),
    (p) => openEdit(p)
  );

  const handleDelete = useCallback(async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await promptRepo.delete(deleteTarget.id);
      bus.emit('prompts:changed');
      toast({
        title: 'Prompt deleted',
        description: `“${deleteTarget.title}” was removed from your library.`,
      });
      setDeleteTarget(null);
    } catch (err) {
      toast({
        title: 'Could not delete prompt',
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
          title="Prompts"
          description="Reusable system prompts and message starters."
          actions={
            <Button onClick={openNew}>
              <Plus aria-hidden />
              New prompt
            </Button>
          }
        />

        {prompts === null ? (
          <div className="grid gap-3 sm:grid-cols-2" aria-hidden>
            {Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="h-40 rounded-xl" />
            ))}
          </div>
        ) : prompts.length === 0 ? (
          <div className="mt-4">
            <EmptyState
              icon={MessageSquareText}
              title="No prompts yet"
              description="Save the prompts you keep retyping — then load one into a new chat with a single click."
              action={
                <Button onClick={openNew}>
                  <Plus aria-hidden />
                  New prompt
                </Button>
              }
            />
          </div>
        ) : (
          <>
            <ListToolbar>
              <div className="relative w-full sm:w-64">
                <Search
                  className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
                  aria-hidden
                />
                <Input
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="Search prompts…"
                  aria-label="Search prompts"
                  className="w-full pl-8"
                />
              </div>
              {categories.length > 0 && (
                <div
                  className="flex flex-wrap items-center gap-1.5"
                  role="group"
                  aria-label="Filter by category"
                >
                  {[{ id: 'all', label: 'All' }, ...categories.map((c) => ({ id: c, label: c }))].map(
                    (chip) => (
                      <button
                        key={chip.id}
                        type="button"
                        onClick={() => setCategory(chip.id)}
                        aria-pressed={category === chip.id}
                        className={cn(
                          'rounded-full border px-3 py-1 text-xs transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
                          category === chip.id
                            ? 'border-transparent bg-brand font-medium text-brand-foreground'
                            : 'border-border text-muted-foreground hover:text-foreground'
                        )}
                      >
                        {chip.label}
                      </button>
                    )
                  )}
                </div>
              )}
            </ListToolbar>

            {visible.length === 0 ? (
              <div className="rounded-xl border border-dashed border-border px-6 py-10 text-center">
                <p className="text-sm text-muted-foreground">
                  {query.trim()
                    ? `No prompts match “${query.trim()}”.`
                    : 'No prompts in this category.'}
                </p>
                {(query.trim() || category !== 'all') && (
                  <Button
                    variant="outline"
                    size="sm"
                    className="mt-3"
                    onClick={() => {
                      setQuery('');
                      setCategory('all');
                    }}
                  >
                    Clear search and filters
                  </Button>
                )}
              </div>
            ) : (
              <ul className="grid gap-3 sm:grid-cols-2">
                {visible.map((prompt) => (
                  <PromptCard
                    key={prompt.id}
                    prompt={prompt}
                    onEdit={openEdit}
                    onDelete={setDeleteTarget}
                  />
                ))}
              </ul>
            )}
          </>
        )}
      </div>

      <PromptDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        prompt={dialogOpen ? editTarget : null}
      />

      <AlertDialog
        open={!!deleteTarget}
        onOpenChange={(open) => {
          if (!open) setDeleteTarget(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete prompt?</AlertDialogTitle>
            <AlertDialogDescription>
              “{deleteTarget?.title}” will be removed from your library. Chats
              you already sent it in keep their messages — only the reusable
              copy is deleted.
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
              Delete prompt
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
