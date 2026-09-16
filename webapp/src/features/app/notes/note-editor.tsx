'use client';

/**
 * NoteEditor — presentational editor for a single note.
 *
 * Title input + content textarea filling the available height, a
 * header with pin / export / delete actions and a live autosave
 * indicator. All persistence lives in the parent (NotesView) so
 * switching notes never loses pending edits.
 */
import { Check, Download, Loader2, Pin, PinOff, Trash2, Wrench } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import type { Note } from '@/lib/types/domain';
import { formatRelativeTime } from '@/lib/utils';
import { MetaPill } from '@/features/app/shared/ui';

export type SaveState = 'idle' | 'saving' | 'saved';

export function NoteEditor({
  note,
  title,
  content,
  saveState,
  onTitleChange,
  onContentChange,
  onTogglePin,
  onExport,
  onDelete,
}: {
  note: Note;
  title: string;
  content: string;
  saveState: SaveState;
  onTitleChange: (value: string) => void;
  onContentChange: (value: string) => void;
  onTogglePin: () => void;
  onExport: () => void;
  onDelete: () => void;
}) {
  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex items-center gap-1.5 border-b border-border px-3 py-2.5 sm:px-4">
        <Input
          value={title}
          onChange={(e) => onTitleChange(e.target.value)}
          placeholder="Note title"
          aria-label="Note title"
          className="h-9 flex-1 border-0 bg-transparent px-1.5 text-[15px] font-semibold shadow-none focus-visible:ring-0"
        />
        <span
          aria-live="polite"
          className="hidden w-[74px] items-center justify-end text-[11px] text-muted-foreground sm:flex"
        >
          {saveState === 'saving' ? (
            <>
              <Loader2 className="mr-1 h-3 w-3 animate-spin" /> Saving…
            </>
          ) : saveState === 'saved' ? (
            <>
              <Check className="mr-1 h-3 w-3 text-success" /> Saved
            </>
          ) : null}
        </span>
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8"
          aria-label={note.pinned ? `Unpin note ${note.title || 'Untitled'}` : `Pin note ${note.title || 'Untitled'}`}
          title={note.pinned ? 'Unpin' : 'Pin'}
          onClick={onTogglePin}
        >
          {note.pinned ? (
            <PinOff className="h-4 w-4" />
          ) : (
            <Pin className="h-4 w-4" />
          )}
        </Button>
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8"
          aria-label={`Export note ${note.title || 'Untitled'} as text file`}
          title="Export .txt"
          onClick={onExport}
        >
          <Download className="h-4 w-4" />
        </Button>
        <Button
          variant="ghost"
          size="icon"
          className="h-8 w-8 text-muted-foreground hover:text-destructive"
          aria-label={`Delete note ${note.title || 'Untitled'}`}
          title="Delete"
          onClick={onDelete}
        >
          <Trash2 className="h-4 w-4" />
        </Button>
      </header>

      <Textarea
        value={content}
        onChange={(e) => onContentChange(e.target.value)}
        placeholder="Start writing — notes autosave as you type and never leave this device."
        aria-label="Note content"
        className="min-h-0 flex-1 resize-none rounded-none border-0 bg-transparent p-4 text-[14px] leading-relaxed shadow-none focus-visible:ring-0 scrollbar-slim"
      />

      <footer className="flex items-center gap-2 border-t border-border px-4 py-2 text-[11px] text-muted-foreground">
        <span
          title={new Date(note.updatedAt).toLocaleString()}
          className="truncate"
        >
          Updated {formatRelativeTime(note.updatedAt)}
        </span>
        {note.createdByTool && (
          <MetaPill tone="outline">
            <Wrench className="h-2.5 w-2.5" /> via {note.createdByTool}
          </MetaPill>
        )}
        <span
          className="ml-auto shrink-0 tabular-nums"
          aria-label={`${content.length} characters`}
        >
          {content.length} chars
        </span>
      </footer>
    </div>
  );
}
