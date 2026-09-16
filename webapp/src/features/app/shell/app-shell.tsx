'use client';

/**
 * AppShell — the application frame.
 *
 * Layout (behavior-based, per the plan):
 *  - Expanded (≥1200px): persistent sidebar + main + inspector.
 *  - Medium (768–1199px): sidebar + main; inspector overlays.
 *  - Compact (<768px): drawer navigation + single column + bottom bar.
 *
 * Routing is hash-based: `#/app/<segments>`. Every feature page is
 * rendered through <RouteContent/> below.
 */
import { useEffect, useMemo } from 'react';
import { useAppStore, useRoute } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';
import { Sidebar } from './sidebar';
import { BottomNav } from './bottom-nav';
import { RouteContent } from './route-content';
import { CommandPalette } from './command-palette';
import { ShortcutsDialog } from './shortcuts-dialog';
import { cn } from '@/lib/utils';
import { pipeline } from '@/lib/services/generation-pipeline';

export function AppShell() {
  const route = useRoute();
  const { hydrated, hydrate, settings } = useAppStore();

  useEffect(() => {
    void hydrate();
  }, [hydrate]);

  // Apply the appearance settings (compact mode / font scale).
  useEffect(() => {
    const root = document.documentElement;
    root.classList.toggle('app-compact', settings.general.compactMode);
    const scale = { sm: '15px', md: '16px', lg: '17.5px' }[settings.appearance.fontSize];
    root.style.fontSize = scale;
    return () => {
      root.style.fontSize = '';
    };
  }, [settings.general.compactMode, settings.appearance.fontSize]);

  // Warn before closing while a generation is streaming.
  useEffect(() => {
    const handler = (e: BeforeUnloadEvent) => {
      if (pipeline.isStreaming()) {
        e.preventDefault();
        e.returnValue = '';
      }
    };
    window.addEventListener('beforeunload', handler);
    return () => window.removeEventListener('beforeunload', handler);
  }, []);

  // Register the installability service worker (network-first shell).
  useEffect(() => {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(() => undefined);
    }
  }, []);

  // Ctrl/Cmd+B — toggle focus mode (collapse the persistent sidebar).
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'b') {
        e.preventDefault();
        useAppStore.getState().setSidebarCollapsed(
          !useAppStore.getState().sidebarCollapsed
        );
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  // Route → page title (document.title) for a11y/context.
  useEffect(() => {
    const seg = route.appSegments;
    const titles: Record<string, string> = {
      chat: 'Chat',
      chats: 'History',
      knowledge: 'Knowledge',
      models: 'Models',
      providers: 'Providers',
      memories: 'Memories',
      personas: 'Personas',
      prompts: 'Prompts',
      skills: 'Skills',
      tags: 'Tags',
      notes: 'Notes',
      audio: 'Audio',
      lab: 'Lab',
      activity: 'Activity',
      network: 'Network',
      errors: 'Errors',
      settings: 'Settings',
      wizard: 'Welcome',
    };
    document.title = seg.length
      ? `${titles[seg[0]] ?? 'App'} · PocketLLM`
      : 'PocketLLM App';
  }, [route.appSegments]);

  if (!hydrated) {
    return (
      <div className="flex h-screen items-center justify-center bg-background">
        <div className="flex flex-col items-center gap-3" role="status" aria-live="polite">
          { }
          <img src="/logo.png" alt="" className="h-12 w-12 rounded-xl animate-pulse" />
          <p className="text-sm text-muted-foreground">Opening local storage…</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-dvh flex-col overflow-hidden bg-background">
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:left-2 focus:top-2 focus:z-[100] focus:rounded-md focus:bg-primary focus:px-3 focus:py-2 focus:text-sm focus:text-primary-foreground"
      >
        Skip to content
      </a>
      <div className="flex min-h-0 flex-1">
        <Sidebar />
        <main
          id="main-content"
          className={cn('relative flex min-w-0 flex-1 flex-col')}
        >
          {/* Fade/slide on route change — keyed by path so in-place updates
              (streaming, typing) never remount the view. */}
          <div key={route.path} className="flex min-h-0 flex-1 flex-col animate-route-in">
            <RouteContent segments={route.appSegments} />
          </div>
        </main>
      </div>
      <BottomNav />
      <CommandPalette />
      <ShortcutsDialog />
    </div>
  );
}
