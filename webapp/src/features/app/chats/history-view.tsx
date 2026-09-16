'use client';

/**
 * HistoryView — conversation manager (route #/app/chats).
 *
 * Search across titles + message bodies, filter chips (pinned /
 * archived / starred / tagged), sort options, date-bucketed groups,
 * row quick actions and a multi-select toolbar with bulk archive,
 * delete and JSON or combined-Markdown export.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Archive,
  Bookmark,
  BookmarkPlus,
  CheckSquare,
  Download,
  FileText,
  Loader2,
  MessagesSquare,
  Pin,
  Plus,
  Search,
  SearchX,
  Star,
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
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Skeleton } from '@/components/ui/skeleton';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import { chatRepo, messageRepo, tagRepo } from '@/lib/core/db/repositories';
import { router } from '@/lib/core/router';
import { chatService } from '@/lib/services/chat-service';
import { settingsService } from '@/lib/services/settings-service';
import type { Chat, Message, Tag } from '@/lib/types/domain';
import { cn, dateBucket } from '@/lib/utils';
import { EmptyState, ListToolbar, PageHeader } from '@/features/app/shared/ui';
import {
  ActivityStrip,
  computeActivityWindow,
} from '@/features/app/shared/activity-sparkline';
import { ChatRow } from './chat-row';
import { exportChats, exportChatsToMarkdown } from './export-chats';
import {
  MessageSearchResults,
  searchMessages,
} from './message-search-results';

type FilterKey = 'all' | 'pinned' | 'archived' | 'starred' | 'tagged';
type SortKey = 'recent' | 'created' | 'title';

const FILTERS: Array<{ key: FilterKey; label: string }> = [
  { key: 'all', label: 'All' },
  { key: 'pinned', label: 'Pinned' },
  { key: 'archived', label: 'Archived' },
  { key: 'starred', label: 'Starred' },
  { key: 'tagged', label: 'Tagged' },
];

const EMPTY_BY_FILTER: Record<FilterKey, { icon: typeof Pin; title: string; description: string }> = {
  all: {
    icon: MessagesSquare,
    title: 'No conversations yet',
    description:
      'Everything you chat about stays on this device. Start a conversation and it will show up here, grouped by day.',
  },
  pinned: {
    icon: Pin,
    title: 'No pinned chats',
    description: 'Pin your go-to conversations with the pin action and they will always sit at the top of this list.',
  },
  archived: {
    icon: Archive,
    title: 'Nothing archived',
    description: 'Chats you archive move here and out of the sidebar — but stay searchable and easy to restore.',
  },
  starred: {
    icon: Star,
    title: 'No starred messages yet',
    description: 'Star any message inside a chat and its conversation will be listed here for quick access.',
  },
  tagged: {
    icon: TagIcon,
    title: 'No tagged chats',
    description: 'Assign tags from a chat’s tag button to organize conversations into topics.',
  },
};

export function HistoryView({ initialFilter }: { initialFilter?: FilterKey } = {}) {
  /* ------------------------------ state ------------------------------ */
  const [query, setQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');
  const [filter, setFilter] = useState<FilterKey>(initialFilter ?? 'all');
  const [sort, setSort] = useState<SortKey>('recent');

  const [allChats, setAllChats] = useState<Chat[]>([]);
  const [tagMap, setTagMap] = useState<Map<string, Tag>>(new Map());
  const [starredIds, setStarredIds] = useState<Set<string>>(new Set());
  /** chatId → messages, kept in memory for message-level search. */
  const [messagesByChat, setMessagesByChat] = useState<Map<string, Message[]>>(new Map());
  const [loading, setLoading] = useState(true);
  const [loadedOnce, setLoadedOnce] = useState(false);

  const [selectMode, setSelectMode] = useState(false);
  const [selection, setSelection] = useState<Set<string>>(new Set());
  const [deleteIds, setDeleteIds] = useState<string[] | null>(null);
  const [busy, setBusy] = useState(false);

  /* Saved searches — persisted through settings (localStorage + event
     bus), so they survive reloads and stay in sync across open views. */
  const [savedQueries, setSavedQueries] = useState<string[]>(() => {
    try {
      return settingsService.get().search?.savedQueries ?? [];
    } catch {
      return [];
    }
  });
  useEffect(() => {
    const refresh = () => {
      try {
        setSavedQueries(settingsService.get().search?.savedQueries ?? []);
      } catch {
        /* unreadable settings — keep the in-memory list */
      }
    };
    return bus.on('settings:changed', refresh);
  }, []);

  /* ---------------------------- debounced search -------------------- */
  useEffect(() => {
    const t = setTimeout(() => setDebouncedQuery(query.trim()), 250);
    return () => clearTimeout(t);
  }, [query]);

  /* ------------------------------- data ------------------------------ */
  const load = useCallback(async () => {
    try {
      const [chats, tags, messages] = await Promise.all([
        debouncedQuery
          ? chatService.searchChats(debouncedQuery, { includeArchived: true })
          : chatService.listChats(true),
        tagRepo.getAll(),
        messageRepo.getAll(),
      ]);
      setAllChats(chats);
      setTagMap(new Map(tags.map((t) => [t.id, t])));
      setStarredIds(
        new Set(messages.filter((m) => m.starred).map((m) => m.chatId))
      );
      const grouped = new Map<string, Message[]>();
      for (const m of messages) {
        const arr = grouped.get(m.chatId);
        if (arr) arr.push(m);
        else grouped.set(m.chatId, [m]);
      }
      setMessagesByChat(grouped);
    } catch (err) {
      toast({
        title: 'Could not load chats',
        description:
          err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
      setLoadedOnce(true);
    }
  }, [debouncedQuery]);

  useEffect(() => {
    void load();
  }, [load]);

  // Refresh when the domain changes elsewhere in the app (throttled —
  // message events fire in bursts while streaming).
  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | null = null;
    const schedule = () => {
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => void load(), 300);
    };
    const unsubs = [
      bus.on('chats:changed', schedule),
      bus.on('tags:changed', schedule),
      bus.on('messages:changed', schedule),
    ];
    return () => {
      if (timer) clearTimeout(timer);
      unsubs.forEach((u) => u());
    };
  }, [load]);

  // Prune selection when chats disappear.
  useEffect(() => {
    const ids = new Set(allChats.map((c) => c.id));
    setSelection((prev) => {
      const next = new Set([...prev].filter((id) => ids.has(id)));
      return next.size === prev.size ? prev : next;
    });
  }, [allChats]);

  /* ----------------------------- derived ----------------------------- */
  const counts = useMemo(() => {
    const c: Record<FilterKey, number> = {
      all: 0,
      pinned: 0,
      archived: 0,
      starred: 0,
      tagged: 0,
    };
    for (const chat of allChats) {
      if (chat.archived) c.archived += 1;
      else {
        c.all += 1;
        if (chat.pinned) c.pinned += 1;
        if (starredIds.has(chat.id)) c.starred += 1;
        if (chat.tags.length > 0) c.tagged += 1;
      }
    }
    return c;
  }, [allChats, starredIds]);

  /* Global 14-day activity across ALL conversations (kept in sync with
     the same messagesByChat map the message search reads). */
  const activityWindow = useMemo(() => {
    const timestamps: number[] = [];
    for (const msgs of messagesByChat.values()) {
      for (const m of msgs) timestamps.push(m.createdAt);
    }
    return computeActivityWindow(timestamps);
  }, [messagesByChat]);

  const visible = useMemo(() => {
    let list: Chat[];
    switch (filter) {
      case 'pinned':
        list = allChats.filter((c) => !c.archived && c.pinned);
        break;
      case 'archived':
        list = allChats.filter((c) => c.archived);
        break;
      case 'starred':
        list = allChats.filter((c) => !c.archived && starredIds.has(c.id));
        break;
      case 'tagged':
        list = allChats.filter((c) => !c.archived && c.tags.length > 0);
        break;
      default:
        list = allChats.filter((c) => !c.archived);
    }
    const sorted = [...list];
    if (sort === 'created') {
      sorted.sort((a, b) => b.createdAt - a.createdAt);
    } else if (sort === 'title') {
      sorted.sort((a, b) => a.title.localeCompare(b.title));
    } else {
      sorted.sort((a, b) =>
        a.pinned === b.pinned
          ? b.lastMessageAt - a.lastMessageAt
          : a.pinned
            ? -1
            : 1
      );
    }
    return sorted;
  }, [allChats, filter, sort, starredIds]);

  const groups = useMemo(() => {
    if (sort === 'title') {
      return [{ label: '', chats: visible }];
    }
    const tsKey: 'lastMessageAt' | 'createdAt' =
      sort === 'created' ? 'createdAt' : 'lastMessageAt';
    const out: Array<{ label: string; chats: Chat[] }> = [];

    // Pinned chats get their own section on top (recent sort only).
    if (sort === 'recent') {
      const pinned = visible.filter((c) => c.pinned);
      if (pinned.length > 0) out.push({ label: 'Pinned', chats: pinned });
    }

    const rest = sort === 'recent' ? visible.filter((c) => !c.pinned) : visible;
    const buckets = new Map<string, Chat[]>();
    for (const chat of rest) {
      const bucket = dateBucket(chat[tsKey]);
      const arr = buckets.get(bucket);
      if (arr) arr.push(chat);
      else buckets.set(bucket, [chat]);
    }
    for (const [label, chats] of buckets) out.push({ label, chats });
    return out;
  }, [visible, sort]);

  const selectedChats = useMemo(
    () => visible.filter((c) => selection.has(c.id)),
    [visible, selection]
  );
  const allSelected = visible.length > 0 && selectedChats.length === visible.length;

  /* Message-level search hits across ALL chats (including archived —
     search is the one place archived content stays reachable). */
  const messageHits = useMemo(
    () =>
      searchMessages(
        debouncedQuery,
        messagesByChat,
        new Map(allChats.map((c) => [c.id, c]))
      ),
    [debouncedQuery, messagesByChat, allChats]
  );

  /* Distinct terms of the active query — offered as drill-down chips
     (click to re-run the search on that single word). Counts are honest:
     messages containing the term anywhere, independent of the full query. */
  const termStats = useMemo(() => {
    const q = debouncedQuery.trim().toLowerCase();
    if (!q) return [];
    const terms = [...new Set(q.split(/\s+/).filter((t) => t.length >= 2))].slice(0, 6);
    return terms.map((term) => {
      let messagesWithTerm = 0;
      let chatsWithTerm = 0;
      for (const msgs of messagesByChat.values()) {
        const matching = msgs.filter(
          (m) => m.content && m.content.toLowerCase().includes(term)
        );
        if (matching.length > 0) {
          chatsWithTerm += 1;
          messagesWithTerm += matching.length;
        }
      }
      return { term, messagesWithTerm, chatsWithTerm };
    });
  }, [debouncedQuery, messagesByChat]);

  /* ----------------------------- actions ---------------------------- */
  const startChat = async () => {
    try {
      const chat = await chatService.createChat();
      router.navigate(`/app/chat/${chat.id}`);
    } catch (err) {
      toast({
        title: 'Could not create chat',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    }
  };

  const togglePin = async (chat: Chat) => {
    try {
      await chatService.updateChat(chat.id, { pinned: !chat.pinned });
    } catch (err) {
      toast({
        title: 'Could not update chat',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    }
  };

  const toggleArchive = async (chat: Chat) => {
    try {
      await chatService.updateChat(chat.id, { archived: !chat.archived });
      toast({
        title: chat.archived ? 'Chat restored' : 'Chat archived',
        description: chat.archived
          ? `“${chat.title}” is back in your active chats.`
          : `“${chat.title}” moved to the Archived filter. It stays searchable.`,
      });
    } catch (err) {
      toast({
        title: 'Could not update chat',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    }
  };

  const archiveSelected = async () => {
    if (selectedChats.length === 0) return;
    const toArchived = !selectedChats.every((c) => c.archived);
    setBusy(true);
    try {
      const fresh = await Promise.all(
        selectedChats.map((c) => chatRepo.get(c.id))
      );
      await chatRepo.putAll(
        fresh
          .filter((c): c is Chat => Boolean(c))
          .map((c) => ({ ...c, archived: toArchived, updatedAt: Date.now() }))
      );
      bus.emit('chats:changed');
      toast({
        title: toArchived
          ? `Archived ${selectedChats.length} ${selectedChats.length === 1 ? 'chat' : 'chats'}`
          : `Restored ${selectedChats.length} ${selectedChats.length === 1 ? 'chat' : 'chats'}`,
      });
      setSelection(new Set());
    } catch (err) {
      toast({
        title: 'Bulk update failed',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    } finally {
      setBusy(false);
    }
  };

  const exportSelected = async () => {
    if (selectedChats.length === 0) return;
    setBusy(true);
    try {
      const filename = await exportChats(selectedChats);
      toast({
        title: 'Export ready',
        description: `${selectedChats.length} ${selectedChats.length === 1 ? 'chat' : 'chats'} with full message history saved as ${filename}.`,
      });
    } catch (err) {
      toast({
        title: 'Export failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setBusy(false);
    }
  };

  const exportSelectedAsMarkdown = async () => {
    if (selectedChats.length === 0) return;
    setBusy(true);
    try {
      const filename = await exportChatsToMarkdown(selectedChats);
      toast({
        title: 'Markdown export ready',
        description: `${selectedChats.length} ${selectedChats.length === 1 ? 'chat' : 'chats'} combined into one document — ${filename}.`,
      });
    } catch (err) {
      toast({
        title: 'Export failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setBusy(false);
    }
  };

  const exportOne = async (chat: Chat) => {
    try {
      const filename = await exportChats([chat]);
      toast({
        title: 'Export ready',
        description: `“${chat.title}” saved as ${filename}.`,
      });
    } catch (err) {
      toast({
        title: 'Export failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    }
  };

  const exportOneAsMarkdown = async (chat: Chat) => {
    try {
      const filename = await exportChatsToMarkdown([chat]);
      toast({
        title: 'Markdown export ready',
        description: `“${chat.title}” saved as ${filename} — open it in any notes app.`,
      });
    } catch (err) {
      toast({
        title: 'Export failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    }
  };

  const confirmDelete = async () => {
    if (!deleteIds || deleteIds.length === 0) return;
    const n = deleteIds.length;
    setBusy(true);
    try {
      await chatService.deleteChats(deleteIds);
      toast({
        title: `Deleted ${n} ${n === 1 ? 'chat' : 'chats'}`,
        description: 'Messages, branches and tool events were removed.',
      });
      setSelection(new Set());
      setDeleteIds(null);
    } catch (err) {
      toast({
        title: 'Delete failed',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    } finally {
      setBusy(false);
    }
  };

  const toggleSelect = (id: string) => {
    setSelection((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const handleOpen = (chat: Chat) => {
    if (selectMode) toggleSelect(chat.id);
    else router.navigate(`/app/chat/${chat.id}`);
  };

  const exitSelectMode = () => {
    setSelectMode(false);
    setSelection(new Set());
  };

  /* ------------------------- saved searches ------------------------- */
  const trimmedQuery = query.trim();
  const canSaveSearch =
    trimmedQuery.length >= 2 &&
    !savedQueries.some((s) => s.toLowerCase() === trimmedQuery.toLowerCase());

  const saveSearch = () => {
    const q = trimmedQuery;
    if (q.length < 2) return;
    const next = [
      q,
      ...savedQueries.filter((s) => s.toLowerCase() !== q.toLowerCase()),
    ].slice(0, 8);
    settingsService.patch({ search: { savedQueries: next } });
    toast({
      title: 'Search saved',
      description: `“${q}” is one click away in this list.`,
    });
  };

  const removeSavedSearch = (q: string) => {
    settingsService.patch({
      search: { savedQueries: savedQueries.filter((s) => s !== q) },
    });
  };

  // Single-delete target keeps its title for the confirm copy.
  const deleteTargetTitles = useMemo(() => {
    if (!deleteIds) return [];
    return deleteIds
      .map((id) => allChats.find((c) => c.id === id)?.title ?? 'Untitled chat')
      .slice(0, 5);
  }, [deleteIds, allChats]);

  /* ------------------------------ render ---------------------------- */
  const initialLoading = loading && !loadedOnce;
  const isSingleDelete = deleteIds?.length === 1;

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 pb-16 pt-8 sm:px-6">
        <PageHeader
          title="Chats"
          description="Every conversation on this device — searchable by title and message content."
          actions={
            <Button onClick={() => void startChat()}>
              <Plus className="h-4 w-4" /> New chat
            </Button>
          }
        />

        {/* Global activity strip — 14 days across every conversation. */}
        {!initialLoading && (
          <ActivityStrip
            window={activityWindow}
            scopeLabel={`across ${allChats.length} conversation${allChats.length === 1 ? '' : 's'}`}
          />
        )}

        {/* Search + filters + sort */}
        <ListToolbar>
          <div className="relative min-w-[200px] flex-1 sm:max-w-xs">
            <Search className="pointer-events-none absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
            <Input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search titles and messages…"
              aria-label="Search chats"
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

          <div
            className="flex flex-wrap items-center gap-1.5"
            role="group"
            aria-label="Filter chats"
          >
            {FILTERS.map((f) => (
              <button
                key={f.key}
                type="button"
                onClick={() => setFilter(f.key)}
                aria-pressed={filter === f.key}
                className={cn(
                  'rounded-full border px-3 py-1.5 text-xs font-medium transition-colors',
                  filter === f.key
                    ? 'border-transparent bg-brand text-brand-foreground'
                    : 'border-border bg-card text-muted-foreground hover:border-brand-strong/60 hover:text-foreground'
                )}
              >
                {f.label}
                <span
                  className={cn(
                    'ml-1 tabular-nums',
                    filter === f.key
                      ? 'text-brand-foreground/70'
                      : 'text-muted-foreground/70'
                  )}
                >
                  {counts[f.key]}
                </span>
              </button>
            ))}
          </div>

          <div className="ml-auto flex items-center gap-2">
            <Select
              value={sort}
              onValueChange={(v) => setSort(v as SortKey)}
            >
              <SelectTrigger className="h-9 w-[150px]" aria-label="Sort chats">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="recent">Recent activity</SelectItem>
                <SelectItem value="created">Date created</SelectItem>
                <SelectItem value="title">Title A–Z</SelectItem>
              </SelectContent>
            </Select>
            <Button
              variant={selectMode ? 'secondary' : 'outline'}
              size="sm"
              onClick={() => (selectMode ? exitSelectMode() : setSelectMode(true))}
              aria-pressed={selectMode}
            >
              <CheckSquare className="h-4 w-4" />
              {selectMode ? 'Done' : 'Select'}
            </Button>
          </div>
        </ListToolbar>

        {/* Saved searches — one-click re-run chips, persisted in settings */}
        {(savedQueries.length > 0 || canSaveSearch) && !selectMode && (
          <div
            className="mb-5 mt-3 flex flex-wrap items-center gap-1.5"
            role="group"
            aria-label="Saved searches"
          >
            <span
              className="flex items-center gap-1 pr-0.5 text-[10px] font-medium uppercase tracking-wider text-muted-foreground/70"
              aria-hidden
            >
              <Bookmark className="h-3 w-3 text-brand-strong" />
            </span>
            <span className="sr-only">Saved searches</span>
            {savedQueries.map((q) => {
              const active =
                q.toLowerCase() === debouncedQuery.trim().toLowerCase();
              return (
                <span
                  key={q}
                  className={cn(
                    'group/saved inline-flex items-center gap-0.5 rounded-full border py-1 pl-2.5 pr-1 text-[11.5px] transition-colors animate-rise-in',
                    active
                      ? 'border-brand-strong bg-brand-soft/60 text-foreground'
                      : 'border-border bg-card text-muted-foreground hover:border-brand-strong/60 hover:text-foreground'
                  )}
                >
                  <button
                    type="button"
                    onClick={() => setQuery(q)}
                    title={`Run search “${q}”`}
                    className="rounded-full outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  >
                    {q}
                  </button>
                  <button
                    type="button"
                    onClick={() => removeSavedSearch(q)}
                    aria-label={`Remove saved search “${q}”`}
                    title="Remove"
                    className="rounded-full p-0.5 text-muted-foreground/50 transition-colors hover:bg-destructive/10 hover:text-destructive"
                  >
                    <X className="h-2.5 w-2.5" />
                  </button>
                </span>
              );
            })}
            {canSaveSearch && (
              <button
                type="button"
                onClick={saveSearch}
                className="inline-flex items-center gap-1 rounded-full border border-dashed border-border px-2.5 py-1 text-[11.5px] text-muted-foreground transition-colors hover:border-brand-strong/70 hover:text-foreground"
                aria-label={`Save search “${trimmedQuery}”`}
              >
                <BookmarkPlus className="h-3 w-3" aria-hidden />
                Save “{trimmedQuery.length > 24 ? `${trimmedQuery.slice(0, 24)}…` : trimmedQuery}”
              </button>
            )}
          </div>
        )}

        {/* Multi-select toolbar */}
        {selectMode && (
          <div className="sticky top-0 z-20 mb-4 flex flex-wrap items-center gap-2 rounded-xl border border-border bg-card p-2 shadow-sm">
            <span className="ml-1 text-[13px] text-muted-foreground">
              {selectedChats.length} of {visible.length} selected
            </span>
            <Button
              variant="ghost"
              size="sm"
              onClick={() =>
                setSelection(allSelected ? new Set() : new Set(visible.map((c) => c.id)))
              }
              disabled={visible.length === 0}
            >
              {allSelected ? 'Deselect all' : 'Select all'}
            </Button>
            <div className="ml-auto flex flex-wrap items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => void archiveSelected()}
                disabled={selectedChats.length === 0 || busy}
              >
                <Archive className="h-4 w-4" />
                {selectedChats.length > 0 &&
                selectedChats.every((c) => c.archived)
                  ? 'Unarchive'
                  : 'Archive'}
              </Button>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button
                    variant="outline"
                    size="sm"
                    disabled={selectedChats.length === 0 || busy}
                  >
                    <Download className="h-4 w-4" /> Export
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-56">
                  <DropdownMenuItem onClick={() => void exportSelected()}>
                    <Download className="h-4 w-4" />
                    <div className="flex flex-col">
                      <span className="text-[13px]">As JSON</span>
                      <span className="text-[11px] text-muted-foreground">
                        Structured data, re-importable elsewhere
                      </span>
                    </div>
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={() => void exportSelectedAsMarkdown()}>
                    <FileText className="h-4 w-4" />
                    <div className="flex flex-col">
                      <span className="text-[13px]">As Markdown</span>
                      <span className="text-[11px] text-muted-foreground">
                        One combined, readable document
                      </span>
                    </div>
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
              <Button
                variant="destructive"
                size="sm"
                onClick={() => setDeleteIds([...selection])}
                disabled={selectedChats.length === 0 || busy}
              >
                <Trash2 className="h-4 w-4" /> Delete
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={exitSelectMode}
                aria-label="Exit select mode"
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}

        {/* Content */}
        {initialLoading ? (
          <div className="space-y-5" role="status" aria-label="Loading chats">
            {[0, 1, 2].map((g) => (
              <div key={g} className="space-y-2">
                <Skeleton className="h-4 w-24" />
                <Skeleton className="h-[72px] w-full rounded-xl" />
                <Skeleton className="h-[72px] w-full rounded-xl" />
              </div>
            ))}
          </div>
        ) : allChats.length === 0 ? (
          <EmptyState
            icon={MessagesSquare}
            title="No conversations yet"
            description="Everything you chat about stays on this device. Start a conversation and it will show up here, grouped by day."
            action={
              <Button onClick={() => void startChat()}>
                <Plus className="h-4 w-4" /> Start a conversation
              </Button>
            }
          />
        ) : visible.length === 0 && !messageHits.length ? (
          debouncedQuery ? (
            <EmptyState
              icon={SearchX}
              title={`No chats match “${debouncedQuery}”`}
              description="Search looks at chat titles and the contents of every message. Try fewer or different words."
              action={
                <Button variant="outline" onClick={() => setQuery('')}>
                  Clear search
                </Button>
              }
            />
          ) : (
            <EmptyState
              icon={EMPTY_BY_FILTER[filter].icon}
              title={EMPTY_BY_FILTER[filter].title}
              description={EMPTY_BY_FILTER[filter].description}
            />
          )
        ) : (
          <div className="space-y-6">
            <div
              className="flex flex-wrap items-center gap-x-2 gap-y-1.5 text-xs text-muted-foreground"
              aria-live="polite"
            >
              {visible.length > 0 && (
                <span>
                  {visible.length}{' '}
                  {visible.length === 1 ? 'conversation' : 'conversations'}
                  {debouncedQuery ? ` matching “${debouncedQuery}”` : ''}
                </span>
              )}
              {messageHits.length > 0 && (
                <>
                  <span aria-hidden>·</span>
                  <span>
                    {messageHits.length}{' '}
                    {messageHits.length === 1 ? 'message' : 'messages'} in
                    their conversations
                  </span>
                </>
              )}
              {/* Term drill-down — click to narrow the search to one word */}
              {termStats.length > 1 && (
                <span className="flex flex-wrap items-center gap-1">
                  <span aria-hidden>·</span>
                  <span className="sr-only">Narrow the search to a single word:</span>
                  {termStats.map((t) => (
                    <button
                      key={t.term}
                      type="button"
                      onClick={() => setQuery(t.term)}
                      title={`Search just “${t.term}” — ${t.messagesWithTerm} message${t.messagesWithTerm === 1 ? '' : 's'} across ${t.chatsWithTerm} chat${t.chatsWithTerm === 1 ? '' : 's'}`}
                      className="inline-flex items-center gap-0.5 rounded-full border border-border bg-card px-2 py-0.5 text-[11px] text-muted-foreground transition-colors hover:border-brand-strong/60 hover:text-foreground"
                    >
                      {t.term}
                      <span className="tabular-nums text-muted-foreground/70">
                        ×{t.messagesWithTerm}
                      </span>
                    </button>
                  ))}
                </span>
              )}
            </div>
            {groups.map((g) => (
              <section
                key={g.label || 'all-chats'}
                aria-label={g.label || 'All chats'}
              >
                {g.label && (
                  <h3 className="sticky top-0 z-10 -mx-4 bg-background/95 py-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground backdrop-blur sm:-mx-6 sm:px-2">
                    {g.label}
                  </h3>
                )}
                <ul className="space-y-1.5">
                  {g.chats.map((chat) => (
                    <ChatRow
                      key={chat.id}
                      chat={chat}
                      tagMap={tagMap}
                      hasStarred={starredIds.has(chat.id)}
                      selectMode={selectMode}
                      selected={selection.has(chat.id)}
                      onToggleSelect={toggleSelect}
                      onOpen={handleOpen}
                      onTogglePin={(c) => void togglePin(c)}
                      onToggleArchive={(c) => void toggleArchive(c)}
                      onDelete={(c) => setDeleteIds([c.id])}
                      onExport={(c) => void exportOne(c)}
                      onExportMarkdown={(c) => void exportOneAsMarkdown(c)}
                    />
                  ))}
                </ul>
              </section>
            ))}

            {/* Individual matching messages — newest chats first. */}
            <MessageSearchResults query={debouncedQuery} hits={messageHits} />
          </div>
        )}
      </div>

      {/* Delete confirmation (single or bulk) */}
      <AlertDialog
        open={deleteIds !== null}
        onOpenChange={(o) => {
          if (!o && !busy) setDeleteIds(null);
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {isSingleDelete
                ? 'Delete this chat?'
                : `Delete ${deleteIds?.length ?? 0} chats?`}
            </AlertDialogTitle>
            <AlertDialogDescription asChild>
              <div>
                {isSingleDelete ? (
                  <>
                    “{deleteTargetTitles[0]}” will be permanently deleted. This
                    deletes messages, branches and tool events — there is no
                    undo.
                  </>
                ) : (
                  <>
                    These chats will be permanently deleted:
                    <ul className="my-1.5 max-h-28 list-inside list-disc overflow-y-auto scrollbar-slim text-left text-[13px] text-muted-foreground">
                      {deleteTargetTitles.map((t, i) => (
                        <li key={i} className="truncate">
                          {t}
                          {i === 4 && (deleteIds?.length ?? 0) > 5
                            ? ` and ${deleteIds!.length - 5} more`
                            : ''}
                        </li>
                      ))}
                    </ul>
                    This deletes messages, branches and tool events — there is
                    no undo.
                  </>
                )}
              </div>
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
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
