'use client';

/**
 * CommandPalette — global Cmd+K search.
 *
 * One fuzzy surface over everything the app can do: jump to any page,
 * open chats, personas, prompts, notes, documents and quick actions
 * (new chat, toggle theme, export backup…). Fully keyboard-driven
 * with grouped results.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  MessageSquarePlus,
  Search,
  Sun,
  Moon,
  MonitorSmartphone,
  Download,
  Settings,
  Clock,
  MessageSquare,
  BookOpen,
  Boxes,
  Brain,
  Sparkles,
  StickyNote,
  AudioLines,
  FlaskConical,
  Activity,
  Network,
  CircleAlert,
  FileText,
  Wand2,
  Tags,
  Star,
  Keyboard,
  PanelLeft,
} from 'lucide-react';
import { useTheme } from 'next-themes';
import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command';
import {
  chatRepo,
  noteRepo,
  personaRepo,
  promptRepo,
  documentRepo,
  memoryRepo,
  tagRepo,
} from '@/lib/core/db/repositories';
import { chatService } from '@/lib/services/chat-service';
import { router } from '@/lib/core/router';
import { useAppStore, useRoute } from '@/lib/store/app-store';
import { deepLink } from '@/lib/core/deep-link';
import { cn } from '@/lib/utils';

interface PaletteItem {
  id: string;
  group: string;
  label: string;
  hint?: string;
  keywords?: string;
  icon: React.ComponentType<{ className?: string }>;
  action: () => void | Promise<void>;
}

/** Static pages + quick actions. */
function useStaticItems(): PaletteItem[] {
  const { setTheme, resolvedTheme } = useTheme();
  const patchSettings = useAppStore((s) => s.patchSettings);

  return useMemo(
    () => [
      {
        id: 'act:new-chat',
        group: 'Actions',
        label: 'New chat',
        hint: 'fresh conversation',
        icon: MessageSquarePlus,
        action: async () => {
          const chat = await chatService.createChat();
          router.navigate(`/app/chat/${chat.id}`);
        },
      },
      {
        id: 'act:theme-toggle',
        group: 'Actions',
        label: `Switch to ${resolvedTheme === 'dark' ? 'light' : 'dark'} theme`,
        icon: resolvedTheme === 'dark' ? Sun : Moon,
        action: () => {
          const next = resolvedTheme === 'dark' ? 'light' : 'dark';
          setTheme(next);
          patchSettings({ appearance: { theme: next } });
        },
      },
      {
        id: 'act:theme-system',
        group: 'Actions',
        label: 'Follow system theme',
        icon: MonitorSmartphone,
        action: () => {
          setTheme('system');
          patchSettings({ appearance: { theme: 'system' } });
        },
      },
      {
        id: 'act:focus-mode',
        group: 'Actions',
        label: 'Toggle focus mode',
        hint: 'Ctrl+B · hide sidebar',
        keywords: 'sidebar collapse hide',
        icon: PanelLeft,
        action: () =>
          useAppStore
            .getState()
            .setSidebarCollapsed(!useAppStore.getState().sidebarCollapsed),
      },
      {
        id: 'act:shortcuts',
        group: 'Actions',
        label: 'Keyboard shortcuts',
        hint: 'press ?',
        icon: Keyboard,
        action: () => {
          // The dialog listens globally; synthesize the trigger.
          window.dispatchEvent(new KeyboardEvent('keydown', { key: '?' }));
        },
      },
      {
        id: 'act:export-backup',
        group: 'Actions',
        label: 'Export encrypted backup',
        hint: 'Settings → Backup',
        icon: Download,
        action: () => router.navigate('/app/settings/backup'),
      },

      { id: 'page:home', group: 'Go to', label: 'Home', icon: MessageSquare, action: () => router.navigate('/app') },
      { id: 'page:chats', group: 'Go to', label: 'Chats history', icon: Clock, action: () => router.navigate('/app/chats') },
      { id: 'page:starred', group: 'Go to', label: 'Starred messages', icon: Star, action: () => router.navigate('/app/starred') },
      { id: 'page:knowledge', group: 'Go to', label: 'Knowledge', hint: 'documents & RAG', icon: BookOpen, action: () => router.navigate('/app/knowledge') },
      { id: 'page:models', group: 'Go to', label: 'Models', icon: Boxes, action: () => router.navigate('/app/models') },
      { id: 'page:providers', group: 'Go to', label: 'Providers', icon: Settings, action: () => router.navigate('/app/providers') },
      { id: 'page:memories', group: 'Go to', label: 'Memories', icon: Brain, action: () => router.navigate('/app/memories') },
      { id: 'page:personas', group: 'Go to', label: 'Personas', icon: Sparkles, action: () => router.navigate('/app/personas') },
      { id: 'page:prompts', group: 'Go to', label: 'Prompts', icon: Wand2, action: () => router.navigate('/app/prompts') },
      { id: 'page:skills', group: 'Go to', label: 'Skills', icon: Sparkles, action: () => router.navigate('/app/skills') },
      { id: 'page:tags', group: 'Go to', label: 'Tags', icon: Tags, action: () => router.navigate('/app/tags') },
      { id: 'page:notes', group: 'Go to', label: 'Notes', icon: StickyNote, action: () => router.navigate('/app/notes') },
      { id: 'page:audio', group: 'Go to', label: 'Audio', icon: AudioLines, action: () => router.navigate('/app/audio') },
      { id: 'page:lab', group: 'Go to', label: 'Prompt Lab', icon: FlaskConical, action: () => router.navigate('/app/lab/prompt') },
      { id: 'page:compare', group: 'Go to', label: 'Compare models', icon: FlaskConical, action: () => router.navigate('/app/lab/compare') },
      { id: 'page:benchmark', group: 'Go to', label: 'Benchmark', icon: FlaskConical, action: () => router.navigate('/app/lab/benchmark') },
      { id: 'page:activity', group: 'Go to', label: 'Activity', icon: Activity, action: () => router.navigate('/app/activity') },
      { id: 'page:network', group: 'Go to', label: 'Network audit', icon: Network, action: () => router.navigate('/app/network') },
      { id: 'page:errors', group: 'Go to', label: 'Errors', icon: CircleAlert, action: () => router.navigate('/app/errors') },
      { id: 'page:settings', group: 'Go to', label: 'Settings', icon: Settings, action: () => router.navigate('/app/settings/general') },
      { id: 'page:storage', group: 'Go to', label: 'Data & storage', icon: Settings, action: () => router.navigate('/app/settings/storage') },
    ],
    [resolvedTheme, setTheme, patchSettings]
  );
}

/** Async entities loaded once when the palette opens. */
function useEntityItems(open: boolean): PaletteItem[] {
  const [items, setItems] = useState<PaletteItem[]>([]);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    (async () => {
      try {
        const [chats, personas, prompts, notes, documents, memories, tags] = await Promise.all([
          chatRepo.getAll(),
          personaRepo.getAll(),
          promptRepo.getAll(),
          noteRepo.getAll(),
          documentRepo.getAll(),
          memoryRepo.getAll(),
          tagRepo.getAll(),
        ]);
        if (cancelled) return;
        setItems([
          ...chats
            .sort((a, b) => b.lastMessageAt - a.lastMessageAt)
            .slice(0, 25)
            .map((c) => ({
              id: `chat:${c.id}`,
              group: 'Chats',
              label: c.title,
              hint: c.archived ? 'archived' : undefined,
              keywords: c.title,
              icon: MessageSquare,
              action: () => router.navigate(`/app/chat/${c.id}`),
            })),
          ...personas.map((p) => ({
            id: `persona:${p.id}`,
            group: 'Personas',
            label: `${p.emoji} ${p.name}`,
            hint: 'edit',
            keywords: p.name,
            icon: Sparkles,
            // Deep link: the personas view opens this persona's editor.
            action: () => {
              deepLink.set({ kind: 'persona', id: p.id });
              router.navigate('/app/personas');
            },
          })),
          ...prompts.slice(0, 10).map((p) => ({
            id: `prompt:${p.id}`,
            group: 'Prompts',
            label: p.title,
            hint: 'edit',
            keywords: `${p.title} ${p.body}`,
            icon: Wand2,
            action: () => {
              deepLink.set({ kind: 'prompt', id: p.id });
              router.navigate('/app/prompts');
            },
          })),
          ...notes.slice(0, 10).map((n) => ({
            id: `note:${n.id}`,
            group: 'Notes',
            label: n.title || 'Untitled note',
            hint: 'open',
            keywords: `${n.title} ${n.content}`,
            icon: StickyNote,
            action: () => {
              deepLink.set({ kind: 'note', id: n.id });
              router.navigate('/app/notes');
            },
          })),
          ...documents.slice(0, 10).map((d) => ({
            id: `doc:${d.id}`,
            group: 'Documents',
            label: d.name,
            keywords: d.name,
            icon: FileText,
            action: () => router.navigate(`/app/knowledge/${d.id}`),
          })),
          ...memories.slice(0, 10).map((m) => ({
            id: `memory:${m.id}`,
            group: 'Memories',
            label: m.fact,
            hint: m.pinned ? 'pinned' : m.subject,
            keywords: `${m.fact} ${m.subject}`,
            icon: Brain,
            // Deep link: the memories view opens this memory's editor.
            action: () => {
              deepLink.set({ kind: 'memory', id: m.id });
              router.navigate('/app/memories');
            },
          })),
          ...tags.slice(0, 12).map((t) => ({
            id: `tag:${t.id}`,
            group: 'Tags',
            label: t.name,
            hint: 'edit',
            keywords: t.name,
            icon: Tags,
            // Deep link: the tags view opens this tag's editor.
            action: () => {
              deepLink.set({ kind: 'tag', id: t.id });
              router.navigate('/app/tags');
            },
          })),
        ]);
      } catch {
        setItems([]);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [open]);

  return items;
}

export function CommandPalette() {
  const open = useAppStore((s) => s.commandPaletteOpen);
  const setOpen = useAppStore((s) => s.setCommandPaletteOpen);
  const staticItems = useStaticItems();
  const entityItems = useEntityItems(open);
  const route = useRoute();
  const isChat = route.appSegments[0] === 'chat';

  // Global keyboard shortcut: Cmd/Ctrl+K.
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setOpen(!useAppStore.getState().commandPaletteOpen);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [setOpen]);

  const runAction = useCallback(
    (item: PaletteItem) => {
      setOpen(false);
      void Promise.resolve(item.action()).catch(() => undefined);
    },
    [setOpen]
  );

  const grouped = useMemo(() => {
    const order = ['Actions', 'Go to', 'Chats', 'Personas', 'Prompts', 'Notes', 'Documents', 'Memories', 'Tags'];
    const groups = new Map<string, PaletteItem[]>();
    for (const item of [...staticItems, ...entityItems]) {
      const list = groups.get(item.group) ?? [];
      list.push(item);
      groups.set(item.group, list);
    }
    return [...groups.entries()].sort(
      (a, b) => order.indexOf(a[0]) - order.indexOf(b[0])
    );
  }, [staticItems, entityItems]);

  return (
    <>
      {/* Floating trigger pill — the discoverable hint for the shortcut.
          Only on non-chat pages: the chat composer occupies the bottom there
          (the chat header exposes its own search affordance). */}
      <button
        onClick={() => setOpen(true)}
        className={cn(
          'fixed bottom-4 right-4 z-30 hidden items-center gap-2 rounded-full border border-border bg-card/90 px-3 py-2 text-[12px] text-muted-foreground shadow-md backdrop-blur transition-all hover:border-brand-strong hover:text-foreground md:flex',
          (open || isChat) && 'pointer-events-none opacity-0'
        )}
        aria-label="Open command palette (Ctrl+K)"
        aria-keyshortcuts="Ctrl+K"
      >
        <Search className="h-3.5 w-3.5" />
        Search everything
        <kbd className="pointer-events-none rounded border border-border bg-muted px-1.5 py-0.5 font-mono text-[10px] font-semibold">
          ⌘K
        </kbd>
      </button>

      <CommandDialog
        open={open}
        onOpenChange={setOpen}
        title="Command palette"
        description="Search chats, pages and actions"
        className="sm:max-w-xl"
      >
        <CommandInput placeholder="Search chats, pages, actions…" />
        <CommandList className="max-h-[min(420px,60vh)] scrollbar-slim">
          <CommandEmpty className="py-8 text-center text-sm text-muted-foreground">
            No results found.
          </CommandEmpty>
          {grouped.map(([group, items]) => (
            <CommandGroup
              key={group}
              heading={
                <span className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground/80">
                  {group}
                </span>
              }
            >
              {items.map((item) => (
                <CommandItem
                  key={item.id}
                  value={`${item.label} ${item.hint ?? ''} ${item.keywords ?? ''}`}
                  onSelect={() => runAction(item)}
                >
                  <item.icon className="h-4 w-4 shrink-0 text-muted-foreground" />
                  <span className="min-w-0 flex-1 truncate text-[13px]">{item.label}</span>
                  {item.hint && (
                    <span className="shrink-0 text-[11px] text-muted-foreground/70">
                      {item.hint}
                    </span>
                  )}
                </CommandItem>
              ))}
            </CommandGroup>
          ))}
        </CommandList>
        <p className="border-t border-border px-3 py-2 text-[10px] text-muted-foreground/70">
          ↑↓ navigate · ↵ open · esc close
        </p>
      </CommandDialog>
    </>
  );
}
