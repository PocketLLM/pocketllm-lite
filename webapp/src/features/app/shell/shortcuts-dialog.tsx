'use client';

/**
 * ShortcutsDialog — global keyboard cheatsheet, opened with "?".
 *
 * Lists every shortcut the app honors. The "?" key only triggers when the
 * user is not typing in an input/textarea/contenteditable host.
 */
import { useEffect, useState } from 'react';
import { Keyboard, Command, PanelLeft, PanelRight, Search, MessageSquare } from 'lucide-react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

interface ShortcutRow {
  keys?: string[];
  label: string;
  hint?: string;
}

const GROUPS: Array<{ title: string; icon: React.ComponentType<{ className?: string }>; rows: ShortcutRow[] }> = [
  {
    title: 'Everywhere',
    icon: Command,
    rows: [
      { keys: ['Ctrl', 'K'], label: 'Command palette', hint: 'search chats, pages, actions' },
      { keys: ['Ctrl', 'B'], label: 'Toggle sidebar (focus mode)', hint: 'hide/show the navigation column' },
      { keys: ['?'], label: 'This shortcuts panel' },
      { keys: ['Esc'], label: 'Close dialogs and menus' },
      { keys: ['Tab'], label: 'Move between controls', hint: 'focus rings show the way' },
    ],
  },
  {
    title: 'In a chat',
    icon: MessageSquare,
    rows: [
      { keys: ['Enter'], label: 'Send message' },
      { keys: ['Shift', 'Enter'], label: 'New line' },
      { keys: ['Ctrl', 'V'], label: 'Paste image as attachment' },
      { keys: ['/'], label: 'Slash commands', hint: 'at the start of an empty message — prompts, personas, actions' },
      { keys: ['↑', '↓'], label: 'Navigate slash menu' },
      { keys: ['Tab'], label: 'Autocomplete slash command' },
      { keys: ['Esc'], label: 'Dismiss slash menu', hint: 'keeps what you typed' },
      { keys: ['j', 'k'], label: 'Move the message cursor', hint: 'when the composer is not focused — k starts at the newest reply' },
      { keys: ['c'], label: 'Copy the selected message', hint: 'while the j/k cursor is active' },
      { keys: ['s'], label: 'Star the selected message', hint: 'while the j/k cursor is active' },
      { keys: ['Esc'], label: 'Leave message navigation', hint: 'also clears search jump highlights' },
    ],
  },
  {
    title: 'Inspector',
    icon: PanelRight,
    rows: [
      { label: 'Toggle inspector', hint: 'PanelRight button in the chat header (wide screens)' },
      { label: 'Search this conversation', hint: 'inspector search box — jump straight to a message' },
    ],
  },
];

/** True when focus is inside a text-editing host. */
function isTyping(target: EventTarget | null): boolean {
  const el = target as HTMLElement | null;
  if (!el) return false;
  const tag = el.tagName?.toLowerCase();
  return (
    tag === 'input' ||
    tag === 'textarea' ||
    tag === 'select' ||
    el.isContentEditable === true
  );
}

export function ShortcutsDialog() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      // "?" is Shift+"/" on most layouts — match by key value.
      if (e.key === '?' && !isTyping(e.target)) {
        e.preventDefault();
        setOpen((v) => !v);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Keyboard className="h-4 w-4 text-brand-strong" />
            Keyboard shortcuts
          </DialogTitle>
          <DialogDescription>
            PocketLLM is built keyboard-first — every surface is reachable
            without touching the mouse.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {GROUPS.map((group) => (
            <section key={group.title}>
              <h3 className="mb-1.5 flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                <group.icon className="h-3.5 w-3.5 text-brand-strong" />
                {group.title}
              </h3>
              <ul className="space-y-0.5">
                {group.rows.map((row) => (
                  <li
                    key={row.label}
                    className="flex items-center justify-between gap-4 rounded-lg px-2 py-1.5 transition-colors hover:bg-muted/60"
                  >
                    <div className="min-w-0">
                      <p className="text-[13px] leading-tight">{row.label}</p>
                      {row.hint && (
                        <p className="text-[11px] leading-tight text-muted-foreground">
                          {row.hint}
                        </p>
                      )}
                    </div>
                    <span className="flex shrink-0 items-center gap-1">
                      {row.keys?.map((k, i) => (
                        <span key={`${k}-${i}`} className="flex items-center gap-1">
                          {i > 0 && <span className="text-[10px] text-muted-foreground/60">+</span>}
                          <Kbd>{k}</Kbd>
                        </span>
                      ))}
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </div>

        <p className="flex items-center gap-1.5 border-t border-border pt-3 text-[11px] text-muted-foreground">
          <Search className="h-3 w-3" />
          The command palette (Ctrl+K) can do everything listed here and more.
        </p>
      </DialogContent>
    </Dialog>
  );
}

function Kbd({ children }: { children: React.ReactNode }) {
  return (
    <kbd className="rounded-md border border-border bg-muted px-1.5 py-0.5 font-mono text-[10.5px] font-semibold text-foreground shadow-[inset_0_-1px_0_0_rgba(0,0,0,0.08)]">
      {children}
    </kbd>
  );
}
