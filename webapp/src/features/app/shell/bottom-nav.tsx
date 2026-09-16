'use client';

/**
 * BottomNav — compact-phone primary navigation (<768px).
 * Hidden on md+ where the sidebar takes over. Rendered as a normal flex
 * child of the shell column (not fixed) so it can never overlap the
 * composer or page content.
 */
import { MessageSquare, Clock, BookOpen, Boxes, Settings } from 'lucide-react';
import { useRoute } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';
import { useAppStore } from '@/lib/store/app-store';
import { cn } from '@/lib/utils';

const ITEMS = [
  { id: 'home', label: 'Chat', icon: MessageSquare, path: '/app', match: (s: string[]) => s.length === 0 || s[0] === 'chat' },
  { id: 'chats', label: 'History', icon: Clock, path: '/app/chats', match: (s: string[]) => s[0] === 'chats' },
  { id: 'knowledge', label: 'Docs', icon: BookOpen, path: '/app/knowledge', match: (s: string[]) => s[0] === 'knowledge' },
  { id: 'models', label: 'Models', icon: Boxes, path: '/app/models', match: (s: string[]) => ['models', 'providers'].includes(s[0]) },
  { id: 'settings', label: 'Settings', icon: Settings, path: '/app/settings/general', match: (s: string[]) => s[0] === 'settings' },
];

export function BottomNav() {
  const route = useRoute();
  const { setSidebarOpen } = useAppStore();
  const segs = route.appSegments;

  return (
    <nav
      aria-label="Primary"
      className="shrink-0 border-t border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/85 md:hidden"
      style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
    >
      <ul className="grid grid-cols-5">
        {ITEMS.map((item) => {
          const Icon = item.icon;
          const active = item.match(segs);
          return (
            <li key={item.id}>
              <button
                onClick={() => {
                  router.navigate(item.path);
                  setSidebarOpen(false);
                }}
                aria-current={active ? 'page' : undefined}
                className={cn(
                  'flex min-h-[52px] w-full flex-col items-center justify-center gap-0.5 py-1.5 text-[10px] font-medium transition-colors',
                  active ? 'text-foreground' : 'text-muted-foreground'
                )}
              >
                <span
                  className={cn(
                    'flex h-7 w-11 items-center justify-center rounded-full transition-colors',
                    active && 'bg-brand'
                  )}
                >
                  <Icon className="h-4 w-4" />
                </span>
                {item.label}
              </button>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
