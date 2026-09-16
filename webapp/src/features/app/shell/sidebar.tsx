'use client';

/**
 * Sidebar — Cortex-style navigation (compact, power-user dense).
 *
 * Desktop ≥lg: persistent column.
 * Below lg: slides in as a drawer with a scrim.
 */
import { useMemo, useState } from 'react';
import {
  MessageSquarePlus,
  Search,
  Clock,
  BookOpen,
  Boxes,
  FlaskConical,
  Settings,
  Pin,
  X,
  ChevronRight,
  LogOut,
} from 'lucide-react';
import { useAppStore, useRoute } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';
import { chatService } from '@/lib/services/chat-service';
import { settingsService } from '@/lib/services/settings-service';
import { cn, dateBucket } from '@/lib/utils';

interface NavItem {
  id: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  path: string;
  match: (segs: string[]) => boolean;
}

const NAV_ITEMS: NavItem[] = [
  {
    id: 'chats',
    label: 'History',
    icon: Clock,
    path: '/app/chats',
    match: (s) => s[0] === 'chats',
  },
  {
    id: 'knowledge',
    label: 'Knowledge',
    icon: BookOpen,
    path: '/app/knowledge',
    match: (s) => s[0] === 'knowledge',
  },
  {
    id: 'models',
    label: 'Models',
    icon: Boxes,
    path: '/app/models',
    match: (s) => s[0] === 'models' || s[0] === 'providers',
  },
  {
    id: 'lab',
    label: 'Lab',
    icon: FlaskConical,
    path: '/app/lab/prompt',
    match: (s) => s[0] === 'lab',
  },
];

const BOTTOM_ITEMS: NavItem[] = [
  {
    id: 'activity',
    label: 'Activity',
    icon: Clock,
    path: '/app/activity',
    match: (s) => ['activity', 'network', 'errors'].includes(s[0]),
  },
  {
    id: 'settings',
    label: 'Settings',
    icon: Settings,
    path: '/app/settings/general',
    match: (s) => s[0] === 'settings',
  },
];

export function Sidebar() {
  const route = useRoute();
  const { chats, sidebarOpen, setSidebarOpen, settings, sidebarCollapsed } = useAppStore();
  const [search, setSearch] = useState('');

  const openChat = (chatId: string) => {
    router.navigate(`/app/chat/${chatId}`);
    setSidebarOpen(false);
  };

  const startNewChat = async () => {
    const chat = await chatService.createChat();
    router.navigate(`/app/chat/${chat.id}`);
    setSidebarOpen(false);
  };

  // Group recent chats by day bucket (Today / Yesterday / …).
  const grouped = useMemo(() => {
    const filtered = search.trim()
      ? chats.filter((c) => c.title.toLowerCase().includes(search.toLowerCase()))
      : chats;
    const groups: Array<{ label: string; chats: typeof filtered }> = [];
    for (const chat of filtered.slice(0, 30)) {
      const label = chat.pinned ? 'Pinned' : dateBucket(chat.lastMessageAt);
      const group = groups.find((g) => g.label === label);
      if (group) group.chats.push(chat);
      else groups.push({ label, chats: [chat] });
    }
    // Pinned group always first.
    groups.sort((a, b) =>
      a.label === 'Pinned' ? -1 : b.label === 'Pinned' ? 1 : 0
    );
    return groups;
  }, [chats, search]);

  const activeSegs = route.appSegments;
  const currentChatId = activeSegs[0] === 'chat' ? activeSegs[1] : undefined;

  const content = (
    <div className="flex h-full flex-col bg-sidebar text-sidebar-foreground">
      {/* Brand + close (mobile) */}
      <div className="flex h-14 items-center gap-2 px-4 shrink-0">
        <button
          className="flex min-w-0 items-center gap-2"
          onClick={() => router.navigate('/app')}
          aria-label="PocketLLM home"
        >
          { }
          <img src="/logo.png" alt="" className="h-7 w-7 rounded-lg" />
          <span className="font-display text-[15px] font-semibold tracking-tight">
            PocketLLM
          </span>
        </button>
        <span className="ml-auto rounded-full bg-brand px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-brand-foreground">
          Web
        </span>
        <button
          className="ml-1 rounded-md p-1.5 hover:bg-sidebar-accent lg:hidden"
          onClick={() => setSidebarOpen(false)}
          aria-label="Close menu"
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      {/* New chat */}
      <div className="px-3 pb-2">
        <button
          onClick={startNewChat}
          className="flex w-full items-center gap-2 rounded-xl bg-primary px-3 py-2.5 text-sm font-medium text-primary-foreground shadow-sm transition-transform hover:-translate-y-px active:translate-y-0"
        >
          <MessageSquarePlus className="h-4 w-4" />
          New chat
        </button>
      </div>

      {/* Search */}
      <div className="px-3 pb-3">
        <div className="relative">
          <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search chats"
            aria-label="Search chats"
            className="w-full rounded-lg border border-transparent bg-sidebar-accent/60 py-2 pl-8 pr-3 text-[13px] outline-none placeholder:text-muted-foreground/70 focus:border-sidebar-ring focus:bg-background"
          />
        </div>
      </div>

      {/* Navigation */}
      <nav aria-label="Primary" className="px-3">
        <ul className="space-y-0.5">
          {NAV_ITEMS.map((item) => (
            <li key={item.id}>
              <SidebarLink
                item={item}
                active={item.match(activeSegs)}
                onNavigate={() => setSidebarOpen(false)}
              />
            </li>
          ))}
        </ul>
      </nav>

      {/* Recent chats */}
      <div className="mt-4 min-h-0 flex-1 overflow-y-auto scrollbar-slim px-3 pb-4">
        {grouped.length === 0 ? (
          <p className="px-2 py-6 text-center text-xs text-muted-foreground">
            {search ? 'No matching chats' : 'Your chats will appear here'}
          </p>
        ) : (
          grouped.map((group) => (
            <section key={group.label} className="mb-3">
              <h3 className="px-2 pb-1 pt-2 text-[11px] font-medium uppercase tracking-wider text-muted-foreground/80">
                {group.label}
              </h3>
              <ul>
                {group.chats.map((chat) => (
                  <li key={chat.id} className="relative">
                    <button
                      onClick={() => openChat(chat.id)}
                      className={cn(
                        'group flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left text-[13px] text-sidebar-foreground/80 transition-colors hover:bg-sidebar-accent',
                        currentChatId === chat.id &&
                          'bg-sidebar-accent font-medium text-sidebar-foreground'
                      )}
                      aria-current={currentChatId === chat.id ? 'page' : undefined}
                    >
                      {currentChatId === chat.id && (
                        // Brand accent bar — unmistakable active marker.
                        <span
                          aria-hidden="true"
                          className="absolute left-0 top-1/2 h-4 w-[3px] -translate-y-1/2 rounded-full bg-brand-strong"
                        />
                      )}
                      {chat.pinned && <Pin className="h-3 w-3 shrink-0 text-brand-strong" />}
                      <span className="truncate">{chat.title}</span>
                      <span className="ml-auto text-[10px] text-muted-foreground/50">
                        {chat.runtimeId === 'assist' ? '' : chat.runtimeId === 'mock' ? 'sandbox' : chat.runtimeId}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            </section>
          ))
        )}
      </div>

      {/* Bottom nav + profile */}
      <div className="shrink-0 border-t border-sidebar-border px-3 py-2">
        <ul className="space-y-0.5">
          {BOTTOM_ITEMS.map((item) => (
            <li key={item.id}>
              <SidebarLink
                item={item}
                active={item.match(activeSegs)}
                onNavigate={() => setSidebarOpen(false)}
              />
            </li>
          ))}
        </ul>
        <div className="mt-2 flex items-center gap-2 rounded-lg px-2 py-2">
          <div className="flex h-7 w-7 items-center justify-center rounded-full bg-brand text-[11px] font-bold text-brand-foreground">
            {(settings.general.displayName || 'You').slice(0, 1).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[13px] font-medium leading-tight">
              {settings.general.displayName || 'Local user'}
            </p>
            <p className="text-[10px] leading-tight text-muted-foreground">
              {settings.privacy.strictOffline ? 'Strict Offline' : 'Data stays on this device'}
            </p>
          </div>
          <button
            className="rounded-md p-1.5 text-muted-foreground hover:bg-sidebar-accent hover:text-sidebar-foreground"
            onClick={() => {
              // Exit to the marketing site.
              settingsService.patch({
                meta: { lastActiveChatId: currentChatId },
              });
              router.navigate('/');
            }}
            aria-label="Exit to website"
            title="Exit to website"
          >
            <LogOut className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>
    </div>
  );

  return (
    <>
      {/* Desktop persistent sidebar (hidden in focus mode — Ctrl+B) */}
      <aside
        className={cn(
          'hidden w-[264px] shrink-0 border-r border-sidebar-border lg:block',
          sidebarCollapsed && 'lg:hidden'
        )}
      >
        {content}
      </aside>

      {/* Mobile drawer */}
      {sidebarOpen && (
        <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true" aria-label="Navigation menu">
          <button
            className="absolute inset-0 bg-foreground/40 backdrop-blur-[2px]"
            onClick={() => setSidebarOpen(false)}
            aria-label="Close menu"
            tabIndex={-1}
          />
          <div className="absolute inset-y-0 left-0 w-[280px] max-w-[85vw] shadow-2xl animate-in-up">
            {content}
          </div>
        </div>
      )}
    </>
  );
}

function SidebarLink({
  item,
  active,
  onNavigate,
}: {
  item: NavItem;
  active: boolean;
  onNavigate: () => void;
}) {
  const Icon = item.icon;
  return (
    <button
      onClick={() => {
        router.navigate(item.path);
        onNavigate();
      }}
      aria-current={active ? 'page' : undefined}
      className={cn(
        'relative flex w-full items-center gap-2.5 rounded-lg px-2.5 py-2 text-[13px] font-medium text-sidebar-foreground/70 transition-colors hover:bg-sidebar-accent hover:text-sidebar-foreground',
        active && 'bg-sidebar-accent text-sidebar-foreground'
      )}
    >
      {/* Active indicator — a small brand bar pinned to the left edge */}
      {active && (
        <span
          aria-hidden
          className="absolute left-0 top-1/2 h-4 w-[3px] -translate-y-1/2 rounded-full bg-brand-strong"
        />
      )}
      <Icon className={cn('h-4 w-4', active && 'text-brand-strong')} />
      {item.label}
      {active && <ChevronRight className="ml-auto h-3.5 w-3.5 text-muted-foreground/60" />}
    </button>
  );
}
