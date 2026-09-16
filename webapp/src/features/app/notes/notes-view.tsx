'use client';

/**
 * NotesView — notes manager (route #/app/notes).
 *
 * Master–detail on md+: list on the left, editor on the right with
 * debounced autosave (600ms). On small screens the editor opens as a
 * dialog. Notes never leave the device; tool-created notes are
 * labelled with a “via tool” pill.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  FileText,
  Loader2,
  Pin,
  PinOff,
  Plus,
  Search,
  SearchX,
  StickyNote,
  Trash2,
  Wrench,
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
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import { noteRepo } from '@/lib/core/db/repositories';
import { deepLink } from '@/lib/core/deep-link';
import { useDeepLink } from '@/lib/core/use-deep-link';
import type { Note } from '@/lib/types/domain';
import { cn, formatRelativeTime, uuid } from '@/lib/utils';
import { EmptyState, ListToolbar, MetaPill, PageHeader } from '@/features/app/shared/ui';
import { NoteEditor, type SaveState } from './note-editor';

/* ----------------------------- helpers ---------------------------- */

/** Reactive media query (SSR-safe). */
function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(() =>
    typeof window !== 'undefined' ? window.matchMedia(query).matches : false
  );
  useEffect(() => {
    const mql = window.matchMedia(query);
    const update = () => setMatches(mql.matches);
    update();
    mql.addEventListener('change', update);
    return () => mql.removeEventListener('change', update);
  }, [query]);
  return matches;
}

function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.rel = 'noopener';
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1_000);
}

function slugify(text: string): string {
  const slug = text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40);
  return slug || 'untitled';
}

const AUTOSAVE_DELAY_MS = 600;

/* ------------------------------ view ------------------------------ */

export function NotesView() {
  /* ------------------------------ state ------------------------------ */
  const [notes, setNotes] = useState<Note[]>([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [loadedOnce, setLoadedOnce] = useState(false);

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [draft, setDraft] = useState<{ title: string; content: string }>({
    title: '',
    content: '',
  });
  const [saveState, setSaveState] = useState<SaveState>('idle');

  const [mobileOpen, setMobileOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Note | null>(null);
  const [busy, setBusy] = useState(false);

  const isDesktop = useMediaQuery('(min-width: 768px)');

  /** Unsaved edits for the currently selected note. */
  const pendingRef = useRef<{ id: string; title: string; content: string } | null>(null);
  const saveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  /* ------------------------------- data ------------------------------ */
  const load = useCallback(async () => {
    try {
      const all = await noteRepo.getAll();
      all.sort((a, b) =>
        a.pinned === b.pinned ? b.updatedAt - a.updatedAt : a.pinned ? -1 : 1
      );
      setNotes(all);
      // Deep link from the command palette: open this note in the editor.
      const request = deepLink.take('note');
      const target = request ? all.find((n) => n.id === request.id) : undefined;
      if (target && target.id !== selectedId) {
        setSelectedId(target.id);
        setDraft({ title: target.title, content: target.content });
        setSaveState('idle');
        if (!isDesktop) setMobileOpen(true);
      }
    } catch (err) {
      toast({
        title: 'Could not load notes',
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

  useEffect(() => {
    const unsub = bus.on('notes:changed', () => void load());
    return unsub;
  }, [load]);

  /* ----------------------------- autosave ---------------------------- */
  const saveNow = useCallback(async () => {
    if (saveTimerRef.current) {
      clearTimeout(saveTimerRef.current);
      saveTimerRef.current = null;
    }
    const p = pendingRef.current;
    if (!p) return;
    pendingRef.current = null;
    setSaveState('saving');
    try {
      const fresh = await noteRepo.get(p.id);
      if (!fresh) throw new Error('This note no longer exists.');
      await noteRepo.put({
        ...fresh,
        title: p.title,
        content: p.content,
        updatedAt: Date.now(),
      });
      bus.emit('notes:changed');
      setSaveState('saved');
    } catch (err) {
      // Keep the pending edits so the next keystroke retries.
      pendingRef.current = p;
      setSaveState('idle');
      toast({
        title: 'Could not save note',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    }
  }, []);

  /** Fire-and-forget flush used on unmount / tab close. */
  const flushInBackground = useCallback(() => {
    if (saveTimerRef.current) {
      clearTimeout(saveTimerRef.current);
      saveTimerRef.current = null;
    }
    const p = pendingRef.current;
    if (!p) return;
    pendingRef.current = null;
    void noteRepo
      .get(p.id)
      .then((fresh) =>
        fresh
          ? noteRepo.put({
              ...fresh,
              title: p.title,
              content: p.content,
              updatedAt: Date.now(),
            })
          : undefined
      )
      .then(() => bus.emit('notes:changed'))
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    const onBeforeUnload = () => flushInBackground();
    window.addEventListener('beforeunload', onBeforeUnload);
    return () => {
      window.removeEventListener('beforeunload', onBeforeUnload);
      flushInBackground(); // switching views / unmounting
    };
  }, [flushInBackground]);

  /** Discards pending edits (used when deleting the edited note). */
  const discardPending = useCallback((id: string) => {
    if (pendingRef.current?.id !== id) return;
    if (saveTimerRef.current) {
      clearTimeout(saveTimerRef.current);
      saveTimerRef.current = null;
    }
    pendingRef.current = null;
    setSaveState('idle');
  }, []);

  const updateDraft = useCallback(
    (patch: Partial<{ title: string; content: string }>) => {
      setDraft((prev) => {
        const next = { ...prev, ...patch };
        if (selectedId) {
          pendingRef.current = { id: selectedId, ...next };
        }
        return next;
      });
      setSaveState('idle');
      if (saveTimerRef.current) clearTimeout(saveTimerRef.current);
      saveTimerRef.current = setTimeout(() => void saveNow(), AUTOSAVE_DELAY_MS);
    },
    [selectedId, saveNow]
  );

  /* ----------------------------- derived ----------------------------- */
  const visibleNotes = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return notes;
    return notes.filter(
      (n) =>
        n.title.toLowerCase().includes(q) || n.content.toLowerCase().includes(q)
    );
  }, [notes, query]);

  const selectedNote = useMemo(
    () => notes.find((n) => n.id === selectedId) ?? null,
    [notes, selectedId]
  );

  /* ----------------------------- actions ---------------------------- */
  const openNote = useCallback(
    (id: string) => {
      if (id !== selectedId) {
        void saveNow(); // flush edits of the previously open note
        const note = notes.find((n) => n.id === id);
        if (!note) return;
        setSelectedId(id);
        setDraft({ title: note.title, content: note.content });
        setSaveState('idle');
      }
      if (!isDesktop) setMobileOpen(true);
    },
    [selectedId, notes, isDesktop, saveNow]
  );

  // Live deep links: palette selections while this view is already open.
  useDeepLink<Note>(
    'note',
    (id) => notes.find((n) => n.id === id),
    (n) => openNote(n.id)
  );

  const closeMobileEditor = (open: boolean) => {
    if (!open) {
      void saveNow();
      setMobileOpen(false);
    }
  };

  const createNote = async () => {
    setBusy(true);
    try {
      void saveNow(); // flush any pending edits first
      const note: Note = {
        id: uuid(),
        title: '',
        content: '',
        pinned: false,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      };
      await noteRepo.put(note);
      bus.emit('notes:changed');
      setSelectedId(note.id);
      setDraft({ title: '', content: '' });
      setSaveState('idle');
      if (!isDesktop) setMobileOpen(true);
    } catch (err) {
      toast({
        title: 'Could not create note',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    } finally {
      setBusy(false);
    }
  };

  const togglePin = async (note: Note) => {
    try {
      await saveNow(); // persist edits before re-writing the record
      const fresh = await noteRepo.get(note.id);
      if (!fresh) return;
      await noteRepo.put({ ...fresh, pinned: !fresh.pinned });
      bus.emit('notes:changed');
    } catch (err) {
      toast({
        title: 'Could not update note',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    }
  };

  const exportNote = async (note: Note) => {
    try {
      await saveNow();
      const fresh = (await noteRepo.get(note.id)) ?? note;
      const title = fresh.title || 'Untitled note';
      const text = [
        title,
        '',
        fresh.content,
        '',
        '—',
        `PocketLLM · exported ${new Date().toLocaleString()}`,
      ].join('\n');
      const filename = `note-${slugify(title)}.txt`;
      downloadBlob(new Blob([text], { type: 'text/plain;charset=utf-8' }), filename);
      toast({
        title: 'Note exported',
        description: `Saved as ${filename}.`,
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
    if (!deleteTarget) return;
    const id = deleteTarget.id;
    setBusy(true);
    try {
      discardPending(id); // never resurrect a deleted note
      await noteRepo.delete(id);
      bus.emit('notes:changed');
      toast({
        title: 'Note deleted',
        description: `“${deleteTarget.title || 'Untitled note'}” was removed from this device.`,
      });
      if (selectedId === id) {
        setSelectedId(null);
        setMobileOpen(false);
      }
      setDeleteTarget(null);
    } catch (err) {
      toast({
        title: 'Could not delete note',
        description: err instanceof Error ? err.message : 'Local database error.',
        variant: 'destructive',
      });
    } finally {
      setBusy(false);
    }
  };

  const editorProps = selectedNote
    ? {
        note: selectedNote,
        title: draft.title,
        content: draft.content,
        saveState,
        onTitleChange: (v: string) => updateDraft({ title: v }),
        onContentChange: (v: string) => updateDraft({ content: v }),
        onTogglePin: () => void togglePin(selectedNote),
        onExport: () => void exportNote(selectedNote),
        onDelete: () => setDeleteTarget(selectedNote),
      }
    : null;

  /* ------------------------------ render ---------------------------- */
  const initialLoading = loading && !loadedOnce;

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      {/* Header + search */}
      <div className="px-4 pt-8 sm:px-6">
        <div className="mx-auto w-full max-w-5xl">
          <PageHeader
            title="Notes"
            description="Quick thoughts and reference material, stored on this device only. Tools can file notes here too."
            actions={
              <Button onClick={() => void createNote()} disabled={busy}>
                {busy ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Plus className="h-4 w-4" />
                )}
                New note
              </Button>
            }
          />
          <ListToolbar>
            <div className="relative min-w-[200px] flex-1 sm:max-w-xs">
              <Search className="pointer-events-none absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search notes…"
                aria-label="Search notes"
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
            {visibleNotes.length > 0 && (
              <p className="text-xs text-muted-foreground">
                {visibleNotes.length} {visibleNotes.length === 1 ? 'note' : 'notes'}
              </p>
            )}
          </ListToolbar>
        </div>
      </div>

      {/* Master–detail card */}
      <div className="min-h-0 flex-1 px-4 pb-6 sm:px-6">
        <div className="mx-auto flex h-full min-h-0 w-full max-w-5xl overflow-hidden rounded-2xl border border-border bg-card">
          {/* List pane */}
          <aside
            className="w-full overflow-y-auto scrollbar-slim md:w-80 md:shrink-0 md:border-r md:border-border"
            aria-label="Notes list"
          >
            {initialLoading ? (
              <div className="space-y-2 p-3" role="status" aria-label="Loading notes">
                {[0, 1, 2, 3].map((i) => (
                  <Skeleton key={i} className="h-[74px] w-full rounded-xl" />
                ))}
              </div>
            ) : notes.length === 0 ? (
              <div className="p-4">
                <EmptyState
                  icon={StickyNote}
                  title="No notes yet"
                  description="Jot down anything you want to keep — meeting minutes, ideas, context for chats. Tools like the notes tool can also create them for you."
                  action={
                    <Button onClick={() => void createNote()}>
                      <Plus className="h-4 w-4" /> Write your first note
                    </Button>
                  }
                />
              </div>
            ) : visibleNotes.length === 0 ? (
              <div className="p-4">
                <EmptyState
                  icon={SearchX}
                  title={`No notes match “${query.trim()}”`}
                  description="Search covers both titles and note contents. Try fewer words."
                  action={
                    <Button variant="outline" onClick={() => setQuery('')}>
                      Clear search
                    </Button>
                  }
                />
              </div>
            ) : (
              <ul className="p-2">
                {visibleNotes.map((note) => {
                  const active = note.id === selectedId;
                  return (
                    <li key={note.id}>
                      <div
                        className={cn(
                          'group rounded-xl border transition-colors',
                          active
                            ? 'border-brand-strong bg-brand-soft/50'
                            : 'border-transparent hover:border-border hover:bg-muted/50'
                        )}
                      >
                        <div className="flex items-start gap-1 p-2.5">
                          <button
                            type="button"
                            className="flex min-w-0 flex-1 flex-col gap-1 rounded-lg p-1 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-card"
                            onClick={() => openNote(note.id)}
                            aria-current={active ? 'true' : undefined}
                          >
                            <span className="flex min-w-0 items-center gap-1.5">
                              {note.pinned && (
                                <Pin
                                  className="h-3 w-3 shrink-0 fill-brand-strong text-brand-strong"
                                  aria-label="Pinned"
                                />
                              )}
                              <span
                                className={cn(
                                  'truncate text-sm',
                                  note.title
                                    ? 'font-medium'
                                    : 'font-medium italic text-muted-foreground'
                                )}
                              >
                                {note.title || 'Untitled'}
                              </span>
                            </span>
                            <span className="line-clamp-2 min-h-[2rem] text-xs leading-relaxed text-muted-foreground">
                              {note.content || 'Empty note'}
                            </span>
                            <span className="flex items-center gap-1.5 text-[11px] text-muted-foreground">
                              {formatRelativeTime(note.updatedAt)}
                              {note.createdByTool && (
                                <MetaPill tone="outline">
                                  <Wrench className="h-2.5 w-2.5" />
                                  {note.createdByTool}
                                </MetaPill>
                              )}
                            </span>
                          </button>
                          <div className="flex shrink-0 flex-col gap-0.5 opacity-100 transition-opacity md:opacity-0 md:group-hover:opacity-100 md:focus-within:opacity-100">
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-7 w-7"
                              aria-label={note.pinned ? `Unpin note ${note.title || 'Untitled'}` : `Pin note ${note.title || 'Untitled'}`}
                              title={note.pinned ? 'Unpin' : 'Pin'}
                              onClick={() => void togglePin(note)}
                            >
                              {note.pinned ? (
                                <PinOff className="h-3.5 w-3.5" />
                              ) : (
                                <Pin className="h-3.5 w-3.5" />
                              )}
                            </Button>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-7 w-7 text-muted-foreground hover:text-destructive"
                              aria-label={`Delete note ${note.title || 'Untitled'}`}
                              title="Delete"
                              onClick={() => setDeleteTarget(note)}
                            >
                              <Trash2 className="h-3.5 w-3.5" />
                            </Button>
                          </div>
                        </div>
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}
          </aside>

          {/* Editor pane (md+) */}
          <section
            className="hidden min-h-0 flex-1 md:block"
            aria-label="Note editor"
          >
            {editorProps ? (
              <NoteEditor {...editorProps} />
            ) : (
              <div className="flex h-full flex-col items-center justify-center gap-3 p-8 text-center">
                <div className="rounded-2xl bg-muted p-3">
                  <FileText className="h-6 w-6 text-muted-foreground" />
                </div>
                <h2 className="text-[15px] font-medium">No note selected</h2>
                <p className="max-w-xs text-sm text-muted-foreground">
                  Pick a note from the list to read or edit it — or create a
                  new one to capture a thought.
                </p>
                <Button variant="outline" onClick={() => void createNote()}>
                  <Plus className="h-4 w-4" /> New note
                </Button>
              </div>
            )}
          </section>
        </div>
      </div>

      {/* Mobile editor dialog */}
      <Dialog open={mobileOpen && editorProps !== null} onOpenChange={closeMobileEditor}>
        <DialogContent className="flex h-[85vh] flex-col gap-0 overflow-hidden p-0 sm:max-w-2xl">
          <DialogHeader className="sr-only">
            <DialogTitle>Edit note</DialogTitle>
            <DialogDescription>
              Changes are saved automatically.
            </DialogDescription>
          </DialogHeader>
          {editorProps && <NoteEditor {...editorProps} />}
        </DialogContent>
      </Dialog>

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
              Delete note “{deleteTarget?.title || 'Untitled'}”?
            </AlertDialogTitle>
            <AlertDialogDescription>
              The note and its contents will be permanently removed from this
              device. There is no undo.
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
              Delete note
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
