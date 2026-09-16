'use client';

/**
 * TagsView — tag manager (route #/app/tags).
 *
 * Create, rename, recolor and delete tags; inspect which chats use
 * each tag (expandable rows); search by name. Deleting a tag strips
 * it from every chat that references it.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ChevronDown,
  Loader2,
  Pencil,
  Pin,
  Plus,
  Search,
  SearchX,
  Tag as TagIcon,
  Trash2,
  X,
} from 'lucide-react';
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
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import { chatRepo, tagRepo } from '@/lib/core/db/repositories';
import { router } from '@/lib/core/router';
import { chatService } from '@/lib/services/chat-service';
import { deepLink } from '@/lib/core/deep-link';
import { useDeepLink } from '@/lib/core/use-deep-link';
import type { Chat, Tag } from '@/lib/types/domain';
import { cn, formatRelativeTime } from '@/lib/utils';
import { EmptyState, ListToolbar, MetaPill, PageHeader } from '@/features/app/shared/ui';
import { TAG_COLORS, TagDialog } from './tag-dialog';

export function TagsView() {
  /* ------------------------------ state ------------------------------ */
  const [tags, setTags] = useState<Tag[]>([]);
  const [chats, setChats] = useState<Chat[]>([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [loadedOnce, setLoadedOnce] = useState(false);

  const [dialogOpen, setDialogOpen] = useState(false);
  const [dialogTag, setDialogTag] = useState<Tag | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Tag | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  /* ------------------------------- data ------------------------------ */
  const load = useCallback(async () => {
    try {
      const [tagList, chatList] = await Promise.all([
        tagRepo.getAll(),
        chatService.listChats(true),
      ]);
      setTags(tagList.sort((a, b) => a.name.localeCompare(b.name)));
      setChats(chatList);
    } catch (err) {
      toast({
        title: 'Could not load tags',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
      setLoadedOnce(true);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  // Deep link from the command palette: open this tag's editor once
  // the list has loaded (cross-route navigation).
  const consumedDeepLink = useRef(false);
  useEffect(() => {
    if (consumedDeepLink.current || loading) return;
    const request = deepLink.take('tag');
    if (!request) {
      consumedDeepLink.current = true;
      return;
    }
    const target = tags.find((t) => t.id === request.id);
    if (target) openEdit(target);
    consumedDeepLink.current = true;
  }, [loading, tags]);

  // Live deep links: palette selections while this view is already open.
  useDeepLink<Tag>(
    'tag',
    (id) => tags.find((t) => t.id === id),
    (t) => openEdit(t)
  );

  // Refresh when the domain changes elsewhere in the app.
  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | null = null;
    const schedule = () => {
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => void load(), 200);
    };
    const unsubs = [
      bus.on('tags:changed', schedule),
      bus.on('chats:changed', schedule),
    ];
    return () => {
      if (timer) clearTimeout(timer);
      unsubs.forEach((u) => u());
    };
  }, [load]);

  /* ----------------------------- derived ----------------------------- */
  const usage = useMemo(() => {
    const map = new Map<string, Chat[]>();
    for (const chat of chats) {
      for (const tagId of chat.tags) {
        const arr = map.get(tagId);
        if (arr) arr.push(chat);
        else map.set(tagId, [chat]);
      }
    }
    return map;
  }, [chats]);

  const visibleTags = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return tags;
    return tags.filter((t) => t.name.toLowerCase().includes(q));
  }, [tags, query]);

  /* ----------------------------- actions ---------------------------- */
  const openCreate = () => {
    setDialogTag(null);
    setDialogOpen(true);
  };

  const openEdit = (tag: Tag) => {
    setDialogTag(tag);
    setDialogOpen(true);
  };

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    const tag = deleteTarget;
    setBusy(true);
    try {
      // Strip the tag from every chat that references it.
      const all = await chatRepo.getAll();
      const affected = all.filter((c) => c.tags.includes(tag.id));
      if (affected.length > 0) {
        await chatRepo.putAll(
          affected.map((c) => ({
            ...c,
            tags: c.tags.filter((t) => t !== tag.id),
          }))
        );
      }
      await tagRepo.delete(tag.id);
      bus.emit('tags:changed');
      if (affected.length > 0) bus.emit('chats:changed');
      toast({
        title: 'Tag deleted',
        description: affected.length
          ? `“${tag.name}” was removed from ${affected.length} ${
              affected.length === 1 ? 'chat' : 'chats'
            }. The chats themselves are untouched.`
          : `“${tag.name}” was not used by any chat.`,
      });
      if (expandedId === tag.id) setExpandedId(null);
      setDeleteTarget(null);
    } catch (err) {
      toast({
        title: 'Could not delete tag',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    } finally {
      setBusy(false);
    }
  };

  const toggleExpanded = (id: string) => {
    setExpandedId((prev) => (prev === id ? null : id));
  };

  const defaultColorForNew =
    TAG_COLORS[tags.length % TAG_COLORS.length];

  /* ------------------------------ render ---------------------------- */
  const initialLoading = loading && !loadedOnce;
  const usageTotal = useMemo(
    () => chats.filter((c) => !c.archived && c.tags.length > 0).length,
    [chats]
  );

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-3xl px-4 pb-16 pt-8 sm:px-6">
        <PageHeader
          title="Tags"
          description={`Label chats to find them fast. ${tags.length} ${
            tags.length === 1 ? 'tag' : 'tags'
          } · ${usageTotal} tagged ${usageTotal === 1 ? 'chat' : 'chats'}.`}
          actions={
            <Button onClick={openCreate}>
              <Plus className="h-4 w-4" /> New tag
            </Button>
          }
        />

        <ListToolbar>
          <div className="relative min-w-[200px] flex-1 sm:max-w-xs">
            <Search className="pointer-events-none absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search tags…"
              aria-label="Search tags"
              className="h-9 pl-8"
            />
            {query && (
              <button
                type="button"
                onClick={() => setQuery('')}
                aria-label="Clear search"
                className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full p-0.5 text-muted-foreground hover:text-foreground"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            )}
          </div>
          {visibleTags.length > 0 && (
            <p className="text-xs text-muted-foreground">
              {visibleTags.length} {visibleTags.length === 1 ? 'tag' : 'tags'}
            </p>
          )}
        </ListToolbar>

        {initialLoading ? (
          <div className="space-y-2" role="status" aria-label="Loading tags">
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-14 w-full rounded-xl" />
            ))}
          </div>
        ) : tags.length === 0 ? (
          <EmptyState
            icon={TagIcon}
            title="No tags yet"
            description="Create tags like “work” or “research”, then attach them to chats from the History view to keep topics together."
            action={
              <Button onClick={openCreate}>
                <Plus className="h-4 w-4" /> Create your first tag
              </Button>
            }
          />
        ) : visibleTags.length === 0 ? (
          <EmptyState
            icon={SearchX}
            title={`No tags match “${query.trim()}”`}
            description="Tag names are matched as you type. Try a shorter search."
            action={
              <Button variant="outline" onClick={() => setQuery('')}>
                Clear search
              </Button>
            }
          />
        ) : (
          <ul className="space-y-1.5">
            {visibleTags.map((tag) => {
              const taggedChats = usage.get(tag.id) ?? [];
              const expanded = expandedId === tag.id;
              return (
                <li key={tag.id}>
                  <div
                    className={cn(
                      'rounded-xl border bg-card transition-colors',
                      expanded
                        ? 'border-brand-strong/60'
                        : 'border-border hover:border-brand-strong/50'
                    )}
                  >
                    <div className="flex items-center gap-1 p-2 pr-2">
                      <button
                        type="button"
                        className="flex min-w-0 flex-1 items-center gap-2.5 rounded-lg px-1.5 py-1.5 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background"
                        onClick={() => toggleExpanded(tag.id)}
                        aria-expanded={expanded}
                        aria-controls={`tag-chats-${tag.id}`}
                      >
                        <span
                          className="h-3 w-3 shrink-0 rounded-full border border-black/10 dark:border-white/10"
                          style={{ backgroundColor: tag.color }}
                        />
                        <span className="truncate text-sm font-medium">
                          {tag.name}
                        </span>
                        <MetaPill>
                          {taggedChats.length}{' '}
                          {taggedChats.length === 1 ? 'chat' : 'chats'}
                        </MetaPill>
                        <ChevronDown
                          className={cn(
                            'ml-auto h-4 w-4 shrink-0 text-muted-foreground transition-transform',
                            expanded && 'rotate-180'
                          )}
                          aria-hidden
                        />
                      </button>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8"
                        aria-label={`Edit tag ${tag.name}`}
                        title="Edit"
                        onClick={() => openEdit(tag)}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 text-muted-foreground hover:text-destructive"
                        aria-label={`Delete tag ${tag.name}`}
                        title="Delete"
                        onClick={() => setDeleteTarget(tag)}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>

                    {expanded && (
                      <div
                        id={`tag-chats-${tag.id}`}
                        className="border-t border-border p-2"
                      >
                        {taggedChats.length === 0 ? (
                          <p className="px-2 py-2.5 text-[13px] text-muted-foreground">
                            No chats use this tag yet. Attach it from a chat’s
                            tag button in the History view.
                          </p>
                        ) : (
                          <ul className="space-y-0.5">
                            {taggedChats.map((chat) => (
                              <li key={chat.id}>
                                <button
                                  type="button"
                                  onClick={() =>
                                    router.navigate(`/app/chat/${chat.id}`)
                                  }
                                  className="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left transition-colors hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                                >
                                  {chat.pinned && (
                                    <Pin
                                      className="h-3 w-3 shrink-0 fill-brand-strong text-brand-strong"
                                      aria-label="Pinned"
                                    />
                                  )}
                                  <span className="truncate text-[13px]">
                                    {chat.title}
                                  </span>
                                  {chat.archived && (
                                    <MetaPill tone="outline">Archived</MetaPill>
                                  )}
                                  <span
                                    className="ml-auto shrink-0 text-[11px] text-muted-foreground"
                                    title={new Date(chat.lastMessageAt).toLocaleString()}
                                  >
                                    {formatRelativeTime(chat.lastMessageAt)}
                                  </span>
                                </button>
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      {/* Create / edit dialog */}
      <TagDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        tag={dialogTag}
        defaultColor={defaultColorForNew}
      />

      {/* Delete confirmation */}
      <AlertDialog
        open={deleteTarget !== null}
        onOpenChange={(o) => {
          if (!o && !busy) setDeleteTarget(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              Delete tag “{deleteTarget?.name}”?
            </AlertDialogTitle>
            <AlertDialogDescription>
              The tag will be removed from{' '}
              {(deleteTarget && (usage.get(deleteTarget.id)?.length ?? 0)) || 0}{' '}
              {(deleteTarget &&
                ((usage.get(deleteTarget.id)?.length ?? 0) === 1
                  ? 'chat'
                  : 'chats')) ||
                'chats'}
              . The chats themselves are not deleted.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={busy}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              disabled={busy}
              className="bg-destructive text-white hover:bg-destructive/90"
              onClick={(e) => {
                e.preventDefault(); // keep open while deleting
                void confirmDelete();
              }}
            >
              {busy && <Loader2 className="h-4 w-4 animate-spin" />}
              Delete tag
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
