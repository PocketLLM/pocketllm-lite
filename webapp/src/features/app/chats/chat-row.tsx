'use client';

/**
 * ChatRow — a single conversation row for the History manager.
 *
 * Dense, power-user layout: title + meta + tag chips on the left,
 * runtime pill and hover quick actions on the right. On small screens
 * the quick actions collapse into a dropdown menu.
 */
import { useState } from 'react';
import {
  Archive,
  ArchiveRestore,
  Download,
  FileText,
  MessageSquare,
  MoreHorizontal,
  Pencil,
  Pin,
  PinOff,
  Star,
  Tags,
  Trash2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { router } from '@/lib/core/router';
import { chatService } from '@/lib/services/chat-service';
import type { Chat, Tag } from '@/lib/types/domain';
import { cn, formatNumber, formatRelativeTime } from '@/lib/utils';
import { MetaPill } from '@/features/app/shared/ui';
import { toast } from '@/hooks/use-toast';

export const RUNTIME_LABELS: Record<Chat['runtimeId'], string> = {
  assist: 'Assist',
  ollama: 'Ollama',
  openai: 'Endpoint',
  mock: 'Sandbox',
};

export interface ChatRowProps {
  chat: Chat;
  /** All known tags, keyed by id (for resolving chat.tags). */
  tagMap: Map<string, Tag>;
  hasStarred: boolean;
  selectMode: boolean;
  selected: boolean;
  onToggleSelect: (id: string) => void;
  onOpen: (chat: Chat) => void;
  onTogglePin: (chat: Chat) => void;
  onToggleArchive: (chat: Chat) => void;
  onDelete: (chat: Chat) => void;
  onExport: (chat: Chat) => void;
  onExportMarkdown: (chat: Chat) => void;
}

export function ChatRow({
  chat,
  tagMap,
  hasStarred,
  selectMode,
  selected,
  onToggleSelect,
  onOpen,
  onTogglePin,
  onToggleArchive,
  onDelete,
  onExport,
  onExportMarkdown,
}: ChatRowProps) {
  const [tagsOpen, setTagsOpen] = useState(false);
  const [renameOpen, setRenameOpen] = useState(false);
  const [renameValue, setRenameValue] = useState('');

  const openRename = () => {
    setRenameValue(chat.title);
    setRenameOpen(true);
  };

  const commitRename = async () => {
    const title = renameValue.trim().slice(0, 120);
    setRenameOpen(false);
    if (!title || title === chat.title) return; // empty/unchanged = no-op
    try {
      await chatService.updateChat(chat.id, { title });
      toast({
        title: 'Chat renamed',
        description: `Now “${title}” — the sidebar updates in a moment.`,
      });
    } catch (err) {
      toast({
        title: 'Could not rename chat',
        description:
          err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    }
  };

  const resolvedTags = chat.tags
    .map((id) => tagMap.get(id))
    .filter((t): t is Tag => Boolean(t));

  const toggleTag = async (tag: Tag, checked: boolean) => {
    const next = checked
      ? [...chat.tags, tag.id]
      : chat.tags.filter((t) => t !== tag.id);
    try {
      await chatService.updateChat(chat.id, { tags: next });
    } catch (err) {
      toast({
        title: 'Could not update tags',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    }
  };

  return (
    <li>
      <div
        className={cn(
          'group flex items-start gap-3 rounded-xl border bg-card p-3 transition-colors',
          selected
            ? 'border-brand-strong bg-brand-soft/50'
            : 'border-border hover:border-brand-strong/60'
        )}
      >
        {selectMode && (
          <Checkbox
            checked={selected}
            onCheckedChange={() => onToggleSelect(chat.id)}
            aria-label={`Select ${chat.title}`}
            className="mt-1"
          />
        )}

        {/* Clickable body — opens the chat (or toggles selection). */}
        <button
          type="button"
          className="flex min-w-0 flex-1 flex-col gap-1.5 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background rounded-md"
          onClick={() => onOpen(chat)}
          title={`Open “${chat.title}”`}
        >
          <span className="flex min-w-0 items-center gap-1.5">
            {chat.pinned && (
              <Pin className="h-3.5 w-3.5 shrink-0 fill-brand-strong text-brand-strong" aria-label="Pinned" />
            )}
            <span className="truncate text-sm font-medium">{chat.title}</span>
            {hasStarred && (
              <Star
                className="h-3.5 w-3.5 shrink-0 fill-warning text-warning"
                aria-label="Contains starred messages"
              />
            )}
          </span>
          <span className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
            <span title={new Date(chat.lastMessageAt).toLocaleString()}>
              {formatRelativeTime(chat.lastMessageAt)}
            </span>
            <span aria-hidden>·</span>
            <span className="inline-flex items-center gap-1">
              <MessageSquare className="h-3 w-3" />
              {formatNumber(chat.messageCount)}
            </span>
            <MetaPill tone="outline">{RUNTIME_LABELS[chat.runtimeId]}</MetaPill>
            {chat.archived && <MetaPill tone="outline">Archived</MetaPill>}
          </span>
          {resolvedTags.length > 0 && (
            <span className="flex flex-wrap items-center gap-1">
              {resolvedTags.slice(0, 4).map((tag) => (
                <span
                  key={tag.id}
                  className="inline-flex items-center gap-1 rounded-full border border-border px-1.5 py-0.5 text-[10px] text-muted-foreground"
                >
                  <span
                    className="h-1.5 w-1.5 rounded-full"
                    style={{ backgroundColor: tag.color }}
                  />
                  {tag.name}
                </span>
              ))}
              {resolvedTags.length > 4 && (
                <span className="text-[10px] text-muted-foreground">
                  +{resolvedTags.length - 4}
                </span>
              )}
            </span>
          )}
        </button>

        {/* Quick actions */}
        <div className="flex shrink-0 items-center gap-0.5">
          {/* Desktop: inline hover actions */}
          <div className="hidden items-center gap-0.5 opacity-0 transition-opacity focus-within:opacity-100 group-hover:opacity-100 sm:flex">
            <TagsPopover
              chat={chat}
              tags={tagMap}
              open={tagsOpen}
              onOpenChange={setTagsOpen}
              onToggleTag={toggleTag}
            />
            <Button
              variant="ghost"
              size="icon"
              className="h-8 w-8"
              aria-label={chat.pinned ? `Unpin ${chat.title}` : `Pin ${chat.title}`}
              title={chat.pinned ? 'Unpin' : 'Pin'}
              onClick={() => onTogglePin(chat)}
            >
              {chat.pinned ? (
                <PinOff className="h-4 w-4" />
              ) : (
                <Pin className="h-4 w-4" />
              )}
            </Button>
            <Button
              variant="ghost"
              size="icon"
              className="h-8 w-8"
              aria-label={
                chat.archived ? `Restore ${chat.title}` : `Archive ${chat.title}`
              }
              title={chat.archived ? 'Unarchive' : 'Archive'}
              onClick={() => onToggleArchive(chat)}
            >
              {chat.archived ? (
                <ArchiveRestore className="h-4 w-4" />
              ) : (
                <Archive className="h-4 w-4" />
              )}
            </Button>
            <Button
              variant="ghost"
              size="icon"
              className="h-8 w-8 text-muted-foreground hover:text-destructive"
              aria-label={`Delete ${chat.title}`}
              title="Delete"
              onClick={() => onDelete(chat)}
            >
              <Trash2 className="h-4 w-4" />
            </Button>
          </div>

          {/* Mobile: overflow menu */}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="h-8 w-8"
                aria-label={`More actions for ${chat.title}`}
              >
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-48">
              <DropdownMenuItem onClick={() => onOpen(chat)}>
                <MessageSquare className="h-4 w-4" /> Open chat
              </DropdownMenuItem>
              <DropdownMenuItem onClick={openRename}>
                <Pencil className="h-4 w-4" /> Rename
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onTogglePin(chat)}>
                {chat.pinned ? <PinOff className="h-4 w-4" /> : <Pin className="h-4 w-4" />}
                {chat.pinned ? 'Unpin' : 'Pin'}
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onToggleArchive(chat)}>
                {chat.archived ? (
                  <ArchiveRestore className="h-4 w-4" />
                ) : (
                  <Archive className="h-4 w-4" />
                )}
                {chat.archived ? 'Unarchive' : 'Archive'}
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onExport(chat)}>
                <Download className="h-4 w-4" /> Export JSON
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => onExportMarkdown(chat)}>
                <FileText className="h-4 w-4" /> Export Markdown
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                onClick={() => onDelete(chat)}
              >
                <Trash2 className="h-4 w-4" /> Delete
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      {/* Rename dialog — the same affordance as the inline header rename,
          reachable from the row so it is discoverable without hover. */}
      <Dialog open={renameOpen} onOpenChange={setRenameOpen}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Rename chat</DialogTitle>
            <DialogDescription>
              Give “{chat.title}” a clearer name. Only the title changes —
              messages, tags and branches stay untouched.
            </DialogDescription>
          </DialogHeader>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              void commitRename();
            }}
            className="space-y-3"
          >
            <Input
              autoFocus
              value={renameValue}
              onChange={(e) => setRenameValue(e.target.value)}
              maxLength={120}
              aria-label="Chat title"
              placeholder="Chat title"
              onKeyDown={(e) => {
                if (e.key === 'Escape') setRenameOpen(false);
              }}
            />
            <DialogFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => setRenameOpen(false)}
              >
                Cancel
              </Button>
              <Button type="submit" disabled={!renameValue.trim()}>
                Rename
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </li>
  );
}

/* ----------------------- tags popover ----------------------- */

function TagsPopover({
  chat,
  tags,
  open,
  onOpenChange,
  onToggleTag,
}: {
  chat: Chat;
  tags: Map<string, Tag>;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onToggleTag: (tag: Tag, checked: boolean) => Promise<void>;
}) {
  const allTags = [...tags.values()].sort((a, b) => a.name.localeCompare(b.name));

  return (
    <Popover open={open} onOpenChange={onOpenChange}>
      <PopoverTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className={cn(
            'h-8 w-8',
            chat.tags.length > 0 && 'text-brand-strong hover:text-brand-strong'
          )}
          aria-label={`Tags for ${chat.title}`}
          title="Tags"
        >
          <Tags className="h-4 w-4" />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-56 p-2">
        <p className="px-2 pb-1.5 text-xs font-semibold text-muted-foreground">
          Tags
        </p>
        {allTags.length === 0 ? (
          <div className="px-2 py-2">
            <p className="text-[13px] text-muted-foreground">
              No tags yet. Create some in the Tags manager first.
            </p>
            <Button
              variant="outline"
              size="sm"
              className="mt-2 w-full"
              onClick={() => {
                onOpenChange(false);
                router.navigate('/app/tags');
              }}
            >
              Open Tags
            </Button>
          </div>
        ) : (
          <ul className="max-h-64 space-y-0.5 overflow-y-auto scrollbar-slim">
            {allTags.map((tag) => {
              const checked = chat.tags.includes(tag.id);
              return (
                <li key={tag.id}>
                  <label className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 text-[13px] hover:bg-muted">
                    <Checkbox
                      checked={checked}
                      onCheckedChange={(v) => void onToggleTag(tag, v === true)}
                      aria-label={`${checked ? 'Remove' : 'Add'} tag ${tag.name}`}
                    />
                    <span
                      className="h-2.5 w-2.5 shrink-0 rounded-full border border-black/10"
                      style={{ backgroundColor: tag.color }}
                    />
                    <span className="truncate">{tag.name}</span>
                  </label>
                </li>
              );
            })}
          </ul>
        )}
      </PopoverContent>
    </Popover>
  );
}
