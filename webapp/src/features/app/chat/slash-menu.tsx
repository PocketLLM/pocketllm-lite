'use client';

/**
 * SlashCommands — type "/" at the start of an empty composer to open a
 * command menu directly above the input.
 *
 * Two layers:
 *   • `useSlashMenu` — the state machine. Watches the draft, lazily loads
 *     saved prompts and personas from the local database the first time
 *     the menu opens, filters commands, owns the highlighted index and
 *     consumes the keyboard events that belong to the menu.
 *   • `SlashMenu` — the visual popover. Grouped list (Actions / Prompts /
 *     Personas), each row with icon, what-you-type label, description and
 *     a monospace command token. Fully keyboard accessible and announced
 *     to screen readers as a listbox.
 *
 * Everything runs locally; commands that insert prompt bodies or switch
 * personas only touch IndexedDB.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  SquarePen,
  FileDown,
  Printer,
  AlignLeft,
  Lightbulb,
  ListChecks,
  MessageSquareQuote,
  Wand2,
  PanelRight,
  Maximize2,
  Keyboard,
  Bot,
  CornerDownLeft,
  BookOpenText,
} from 'lucide-react';
import { personaRepo, promptRepo } from '@/lib/core/db/repositories';
import type { Persona, Prompt } from '@/lib/types/domain';
import { cn } from '@/lib/utils';

/** What the picker calls back with when a command is chosen. */
export type SlashCommandKind =
  | { type: 'insert'; text: string; label: string }
  | { type: 'action'; action: SlashAction }
  | { type: 'persona'; persona: Persona };

export type SlashAction =
  | 'new-chat'
  | 'export-markdown'
  | 'export-pdf'
  | 'toggle-inspector'
  | 'toggle-focus'
  | 'open-scope'
  | 'open-shortcuts';

export interface SlashCommand {
  id: string;
  /** The literal text the user types, e.g. "/summarize". */
  token: string;
  label: string;
  description: string;
  group: 'Actions' | 'Prompts' | 'Personas';
  icon: React.ComponentType<{ className?: string }>;
  run: () => void;
}

interface UseSlashMenuOptions {
  /** The LIVE composer draft (not the persisted chat.draft). */
  draft: string;
  /** Applies a command picked via keyboard or click. */
  onPick: (pick: SlashCommandKind) => void;
  /** Escaping the menu clears the slash prefix; Tab autocompletes. */
  setDraft: (value: string) => void;
}

/** True when a draft should open the slash menu. */
export function slashQueryFor(draft: string): string | null {
  // Only the very first character position triggers the menu, and only
  // while the draft is a single line — pasted multi-line text never opens.
  if (!draft.startsWith('/')) return null;
  if (draft.includes('\n')) return null;
  const query = draft.slice(1).toLowerCase();
  // A bare "/" plus more than ~24 chars is clearly a path/URL, not a command.
  if (query.length > 24) return null;
  return query;
}

export function useSlashMenu({ draft, onPick, setDraft }: UseSlashMenuOptions) {
  const [prompts, setPrompts] = useState<Prompt[]>([]);
  const [personas, setPersonas] = useState<Persona[]>([]);
  const [index, setIndex] = useState(0);
  const loadedOnce = useRef(false);
  /**
   * The menu only opens for drafts the user is actively typing — a slash
   * draft restored from the database on remount stays quiet until the
   * first real keystroke arrives.
   */
  const [armed, setArmed] = useState(false);

  const query = slashQueryFor(draft);

  // Lazily load prompts + personas the first time the menu could open.
  useEffect(() => {
    if (query === null || loadedOnce.current) return;
    loadedOnce.current = true;
    void promptRepo.getAll().then(setPrompts);
    void personaRepo.getAll().then(setPersonas);
  }, [query]);

  // Keep them fresh if the menu stays open across edits elsewhere.
  useEffect(() => {
    if (query === null) return;
    const t = window.setInterval(() => {
      void promptRepo.getAll().then(setPrompts);
      void personaRepo.getAll().then(setPersonas);
    }, 30_000);
    return () => window.clearInterval(t);
  }, [query]);

  const commands = useMemo<SlashCommand[]>(() => {
    const list: SlashCommand[] = [
      {
        id: 'new-chat',
        token: '/new',
        label: 'New chat',
        description: 'Start a fresh conversation',
        group: 'Actions',
        icon: SquarePen,
        run: () => onPick({ type: 'action', action: 'new-chat' }),
      },
      {
        id: 'export-markdown',
        token: '/export',
        label: 'Export as Markdown',
        description: 'Download this chat as a .md file',
        group: 'Actions',
        icon: FileDown,
        run: () => onPick({ type: 'action', action: 'export-markdown' }),
      },
      {
        id: 'export-pdf',
        token: '/print',
        label: 'Export as PDF',
        description: 'Open the print-ready view',
        group: 'Actions',
        icon: Printer,
        run: () => onPick({ type: 'action', action: 'export-pdf' }),
      },
      {
        id: 'open-scope',
        token: '/scope',
        label: 'Set knowledge scope',
        description: 'Restrict retrieval to specific documents',
        group: 'Actions',
        icon: BookOpenText,
        run: () => onPick({ type: 'action', action: 'open-scope' }),
      },
      {
        id: 'summarize',
        token: '/summarize',
        label: 'Summarize the chat',
        description: 'Inserts a summary request',
        group: 'Actions',
        icon: AlignLeft,
        run: () =>
          onPick({
            type: 'insert',
            label: 'Summarize the chat',
            text: 'Summarize this conversation so far. List the key points and any decisions made.',
          }),
      },
      {
        id: 'key-points',
        token: '/points',
        label: 'Extract key points',
        description: 'Ask for a structured breakdown',
        group: 'Actions',
        icon: ListChecks,
        run: () =>
          onPick({
            type: 'insert',
            label: 'Extract key points',
            text: 'Break down your last answer into a short bulleted list of key points.',
          }),
      },
      {
        id: 'example',
        token: '/example',
        label: 'Show an example',
        description: 'Ask for a concrete example',
        group: 'Actions',
        icon: Lightbulb,
        run: () =>
          onPick({
            type: 'insert',
            label: 'Show an example',
            text: 'Give me a concrete, realistic example of that.',
          }),
      },
      {
        id: 'simpler',
        token: '/simpler',
        label: 'Explain more simply',
        description: 'Plain language, shorter',
        group: 'Actions',
        icon: MessageSquareQuote,
        run: () =>
          onPick({
            type: 'insert',
            label: 'Explain more simply',
            text: 'Explain that more simply, in plain language without jargon.',
          }),
      },
      {
        id: 'detail',
        token: '/detail',
        label: 'Go deeper',
        description: 'Ask for details and edge cases',
        group: 'Actions',
        icon: Wand2,
        run: () =>
          onPick({
            type: 'insert',
            label: 'Go deeper',
            text: 'Go deeper on this — cover the details, caveats and edge cases.',
          }),
      },
      {
        id: 'toggle-inspector',
        token: '/inspector',
        label: 'Toggle inspector',
        description: 'Show or hide the context panel',
        group: 'Actions',
        icon: PanelRight,
        run: () => onPick({ type: 'action', action: 'toggle-inspector' }),
      },
      {
        id: 'toggle-focus',
        token: '/focus',
        label: 'Toggle focus mode',
        description: 'Hide the sidebar for full-width chat',
        group: 'Actions',
        icon: Maximize2,
        run: () => onPick({ type: 'action', action: 'toggle-focus' }),
      },
      {
        id: 'shortcuts',
        token: '/help',
        label: 'Keyboard shortcuts',
        description: 'Open the shortcut reference',
        group: 'Actions',
        icon: Keyboard,
        run: () => onPick({ type: 'action', action: 'open-shortcuts' }),
      },
    ];

    for (const p of prompts) {
      list.push({
        id: `prompt-${p.id}`,
        token: `/prompt ${p.title.toLowerCase()}`,
        label: p.title,
        description: p.category ? `Prompt · ${p.category}` : 'Saved prompt',
        group: 'Prompts',
        icon: Bot,
        run: () => onPick({ type: 'insert', label: p.title, text: p.body }),
      });
    }
    for (const persona of personas) {
      list.push({
        id: `persona-${persona.id}`,
        token: `/persona ${persona.name.toLowerCase()}`,
        label: `${persona.emoji} ${persona.name}`,
        description: 'Switch this chat to this persona',
        group: 'Personas',
        icon: Bot,
        run: () => onPick({ type: 'persona', persona }),
      });
    }
    return list;
  }, [prompts, personas, onPick]);

  // Persona runs need the persona id — attached directly in the command
  // payload above; no lookup layer needed.

  const filtered = useMemo(() => {
    if (!query) return commands;
    const q = query;
    return commands.filter((c) => {
      const token = c.token.toLowerCase();
      // "prompt sum" matches "/prompt summarize …" tokens too.
      if (token.startsWith(`/${q}`)) return true;
      if (c.label.toLowerCase().includes(q)) return true;
      // Also match "prompt <name>" style queries.
      if (q.includes(' ') && token.startsWith(`/${q.split(' ')[0]}`) && c.token.includes(q)) return true;
      return false;
    });
  }, [commands, query]);

  // Reset the highlight whenever the filtered set changes shape.
  useEffect(() => {
    setIndex(0);
  }, [query]);

  const open = query !== null && filtered.length > 0 && armed;
  /**
   * Keyboard routing for the composer textarea. Returns true when the
   * keypress was consumed by the menu (↑/↓/Tab/Enter/Escape while open).
   */
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLTextAreaElement>): boolean => {
      // Any real keystroke arms the menu for this mount — restored slash
      // drafts stay quiet until the user actually types.
      setArmed(true);
      if (!open) return false;
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setIndex((i) => (i + 1) % filtered.length);
        return true;
      }
      if (e.key === 'ArrowUp') {
        e.preventDefault();
        setIndex((i) => (i - 1 + filtered.length) % filtered.length);
        return true;
      }
      if (e.key === 'Tab') {
        e.preventDefault();
        // Tab autocompletes the highlighted token into the draft.
        const cmd = filtered[index];
        if (cmd) setDraft(`${cmd.token.split(' ')[0]} `);
        return true;
      }
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        const cmd = filtered[index];
        if (cmd) cmd.run();
        return true;
      }
      if (e.key === 'Escape') {
        e.preventDefault();
        // Close the menu by removing just the slash prefix — the rest of
        // what the user typed stays in the composer as plain text.
        setArmed(false);
        setDraft(draft.replace(/^\/[^\n]*/, (m) => m.slice(1)));
        return true;
      }
      return false;
    },
    [open, filtered, index, onPick, setDraft, draft]
  );

  return {
    open,
    query,
    filtered,
    index,
    setIndex,
    handleKeyDown,
    prompts,
    personas,
  };
}

/**
 * The visual menu. Rendered by the composer as an absolutely positioned
 * listbox directly above the input. Highlighted row is synced with the
 * hook's keyboard navigation.
 */
export function SlashMenu({
  filtered,
  index,
  setIndex,
  onPickRow,
}: {
  filtered: SlashCommand[];
  index: number;
  setIndex: (i: number) => void;
  onPickRow: (command: SlashCommand) => void;
}) {
  const listRef = useRef<HTMLDivElement>(null);

  // Keep the highlighted row in view when navigating with the keyboard.
  useEffect(() => {
    listRef.current
      ?.querySelector(`[data-index="${index}"]`)
      ?.scrollIntoView({ block: 'nearest' });
  }, [index]);

  // Group commands preserving their order of first appearance.
  const groups = useMemo(() => {
    const map = new Map<string, SlashCommand[]>();
    for (const c of filtered) {
      const arr = map.get(c.group) ?? [];
      arr.push(c);
      map.set(c.group, arr);
    }
    return [...map.entries()];
  }, [filtered]);

  let rowIndex = -1;

  return (
    <div
      className="absolute bottom-full left-0 right-0 z-40 mb-2 overflow-hidden rounded-xl border border-border bg-popover shadow-lg animate-pop-in"
      role="listbox"
      aria-label="Slash commands"
    >
      <div
        ref={listRef}
        className="max-h-72 overflow-y-auto scrollbar-slim p-1.5"
      >
        {groups.map(([group, items]) => (
          <div key={group} className="mb-1 last:mb-0">
            <p className="px-2 pb-1 pt-1.5 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
              {group}
            </p>
            {items.map((c) => {
              rowIndex += 1;
              const i = rowIndex;
              const Icon = c.icon;
              return (
                <button
                  key={c.id}
                  type="button"
                  role="option"
                  aria-selected={i === index}
                  data-index={i}
                  onMouseEnter={() => setIndex(i)}
                  onClick={() => onPickRow(c)}
                  className={cn(
                    'flex w-full items-center gap-2.5 rounded-lg px-2 py-1.5 text-left transition-colors',
                    i === index ? 'bg-muted' : 'hover:bg-muted/60'
                  )}
                >
                  <span
                    className={cn(
                      'flex h-7 w-7 shrink-0 items-center justify-center rounded-md border',
                      i === index
                        ? 'border-brand-strong bg-brand-soft text-brand-foreground dark:bg-brand/15'
                        : 'border-border bg-card text-muted-foreground'
                    )}
                  >
                    <Icon className="h-3.5 w-3.5" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13px] font-medium">
                      {c.label}
                    </span>
                    <span className="block truncate text-[11px] text-muted-foreground">
                      {c.description}
                    </span>
                  </span>
                  <code className="hidden shrink-0 rounded border border-border bg-muted/60 px-1.5 py-0.5 font-mono text-[10px] text-muted-foreground sm:block">
                    {c.token.split(' ')[0]}
                  </code>
                  {i === index && (
                    <CornerDownLeft
                      className="h-3 w-3 shrink-0 text-muted-foreground/60"
                      aria-hidden
                    />
                  )}
                </button>
              );
            })}
          </div>
        ))}
      </div>
      <div className="flex items-center gap-3 border-t border-border bg-muted/40 px-3 py-1.5 text-[10px] text-muted-foreground">
        <span className="flex items-center gap-1">
          <kbd className="rounded border border-border bg-background px-1 font-mono">↑↓</kbd>
          navigate
        </span>
        <span className="flex items-center gap-1">
          <kbd className="rounded border border-border bg-background px-1 font-mono">↵</kbd>
          run
        </span>
        <span className="flex items-center gap-1">
          <kbd className="rounded border border-border bg-background px-1 font-mono">esc</kbd>
          dismiss
        </span>
        <span className="ml-auto hidden sm:inline">Runs locally — never sent anywhere</span>
      </div>
    </div>
  );
}
