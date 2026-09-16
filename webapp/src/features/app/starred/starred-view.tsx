'use client';

/**
 * StarredView — every starred message across all chats, with context.
 * Click a card to jump straight into the conversation.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Star, MessageSquare, Search, Trash2, CornerUpRight } from 'lucide-react';
import { messageRepo, chatRepo } from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { chatService } from '@/lib/services/chat-service';
import { router } from '@/lib/core/router';
import { deepLink } from '@/lib/core/deep-link';
import { PageHeader, EmptyState, MetaPill } from '@/features/app/shared/ui';
import { MarkdownMessage } from '@/features/app/shared/markdown-message';
import { Button } from '@/components/ui/button';
import { cn, formatRelativeTime } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type { Chat, Message } from '@/lib/types/domain';

interface StarredEntry {
  message: Message;
  chat: Chat;
}

export function StarredView() {
  const [entries, setEntries] = useState<StarredEntry[]>([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    const [messages, chats] = await Promise.all([
      messageRepo.getAll(),
      chatRepo.getAll(),
    ]);
    const chatById = new Map(chats.map((c) => [c.id, c] as const));
    const starred = messages
      .filter((m) => m.starred)
      .map((message) => {
        const chat = chatById.get(message.chatId);
        return chat ? { message, chat } : null;
      })
      .filter((e): e is StarredEntry => e !== null)
      .sort((a, b) => b.message.updatedAt - a.message.updatedAt);
    setEntries(starred);
    setLoading(false);
  }, []);

  useEffect(() => {
    void load();
    const unsubs = [
      bus.on('messages:changed', () => void load()),
      bus.on('chats:changed', () => void load()),
    ];
    return () => unsubs.forEach((u) => u());
  }, [load]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return entries;
    return entries.filter(
      (e) =>
        e.message.content.toLowerCase().includes(q) ||
        e.chat.title.toLowerCase().includes(q)
    );
  }, [entries, search]);

  const unstar = async (message: Message) => {
    await chatService.updateMessage(message.id, { starred: false });
    toast({ title: 'Removed from starred' });
  };

  /**
   * Continue in chat — jumps into the conversation right at this
   * message (scroll + brand flash, same treatment as search jumps) and
   * focuses the composer so typing can continue immediately.
   */
  const continueInChat = (message: Message, chat: Chat) => {
    deepLink.set({ kind: 'message', id: message.id, chatId: chat.id });
    router.navigate(`/app/chat/${chat.id}`);
    // The composer focus lands after the chat view mounts.
    window.setTimeout(() => {
      window.dispatchEvent(new CustomEvent('pocketllm:focus-composer'));
    }, 350);
  };

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-3xl px-4 py-6 pb-24 sm:px-6">
        <PageHeader
          title="Starred"
          description={`${entries.length} starred message${entries.length === 1 ? '' : 's'} across your chats. Unstarring here unstars it everywhere.`}
        />

        {entries.length > 0 && (
          <div className="relative mb-4">
            <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Filter starred messages"
              aria-label="Filter starred messages"
              className="w-full rounded-lg border border-border bg-card py-2 pl-8 pr-3 text-[13px] outline-none focus:border-brand-strong sm:w-96"
            />
          </div>
        )}

        {loading ? (
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="h-24 animate-pulse rounded-xl bg-muted" />
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            icon={Star}
            title={search ? 'No matching starred messages' : 'No starred messages yet'}
            description={
              search
                ? 'Try a different search.'
                : 'Star any message in a chat (the star icon under a reply) and it will be collected here for quick access.'
            }
          />
        ) : (
          <ul className="space-y-3">
            {filtered.map(({ message, chat }) => (
              <li
                key={message.id}
                className="group rounded-xl border border-border bg-card p-4 transition-all hover:border-brand-strong hover:shadow-md"
              >
                <div className="mb-2 flex flex-wrap items-center gap-2 text-[12px] text-muted-foreground">
                  <Star className="h-3.5 w-3.5 fill-brand text-brand-strong" aria-hidden />
                  <button
                    className="font-medium text-foreground underline-offset-2 hover:underline"
                    onClick={() => router.navigate(`/app/chat/${chat.id}`)}
                    aria-label={`Open chat: ${chat.title}`}
                  >
                    {chat.title}
                  </button>
                  <span aria-hidden>·</span>
                  <span>{formatRelativeTime(message.updatedAt)}</span>
                  {message.role === 'assistant' ? (
                    <MetaPill>assistant</MetaPill>
                  ) : (
                    <MetaPill tone="outline">you</MetaPill>
                  )}
                  <span className="ml-auto flex items-center gap-1 opacity-0 transition-opacity focus-within:opacity-100 group-hover:opacity-100">
                    <button
                      onClick={() => void unstar(message)}
                      className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-destructive"
                      aria-label="Remove from starred"
                      title="Remove from starred"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                    <Button
                      size="sm"
                      onClick={() => continueInChat(message, chat)}
                      title="Jump to this message and keep chatting"
                    >
                      <CornerUpRight className="h-3.5 w-3.5" /> Continue
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => router.navigate(`/app/chat/${chat.id}`)}
                    >
                      <MessageSquare className="h-3.5 w-3.5" /> Open
                    </Button>
                  </span>
                </div>
                <div
                  className={cn(
                    'max-h-40 overflow-y-auto scrollbar-slim rounded-lg border border-border/60 p-3',
                    message.role === 'user' ? 'bg-muted/40' : ''
                  )}
                >
                  {message.role === 'user' ? (
                    <p className="whitespace-pre-wrap text-[14px]">{message.content}</p>
                  ) : (
                    <MarkdownMessage content={message.content} />
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
