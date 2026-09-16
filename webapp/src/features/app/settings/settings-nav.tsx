'use client';

/**
 * Settings navigation — section registry, sticky desktop sidebar list
 * and a mobile scrollable tab row. Both navigate the hash route
 * `#/app/settings/<section>`.
 */
import {
  Accessibility,
  Archive,
  BookOpen,
  Brain,
  Database,
  Globe,
  Info,
  Languages,
  MessageSquare,
  Palette,
  ShieldCheck,
  UserRound,
  Wrench,
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { router } from '@/lib/core/router';

export interface SettingsSectionMeta {
  id: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  group: string;
  description: string;
}

export const SETTINGS_SECTIONS: SettingsSectionMeta[] = [
  {
    id: 'general',
    label: 'General',
    icon: UserRound,
    group: 'Preferences',
    description: 'Your display name and basic input behaviour.',
  },
  {
    id: 'appearance',
    label: 'Appearance',
    icon: Palette,
    group: 'Preferences',
    description: 'Theme, text size and accent, with a live preview.',
  },
  {
    id: 'chat',
    label: 'Chat',
    icon: MessageSquare,
    group: 'Preferences',
    description: 'Default runtime, model and message behaviour.',
  },
  {
    id: 'memory',
    label: 'Memory',
    icon: Brain,
    group: 'Preferences',
    description: 'What the assistant remembers between chats.',
  },
  {
    id: 'knowledge',
    label: 'Knowledge',
    icon: BookOpen,
    group: 'Preferences',
    description: 'Defaults for document retrieval.',
  },
  {
    id: 'tools',
    label: 'Tools',
    icon: Wrench,
    group: 'Preferences',
    description: 'Which built-in tools the assistant may use.',
  },
  {
    id: 'accessibility',
    label: 'Accessibility',
    icon: Accessibility,
    group: 'Preferences',
    description: 'Motion, text size and keyboard reference.',
  },
  {
    id: 'language',
    label: 'Language',
    icon: Languages,
    group: 'Preferences',
    description: 'Locale for dates and numbers.',
  },
  {
    id: 'privacy',
    label: 'Privacy',
    icon: ShieldCheck,
    group: 'Privacy & data',
    description: 'Strict Offline and network permissions.',
  },
  {
    id: 'network',
    label: 'Network',
    icon: Globe,
    group: 'Privacy & data',
    description: 'What this app is allowed to contact, and why.',
  },
  {
    id: 'storage',
    label: 'Data & Storage',
    icon: Database,
    group: 'Privacy & data',
    description: 'Storage usage, log retention, cleanup and resets.',
  },
  {
    id: 'backup',
    label: 'Backup',
    icon: Archive,
    group: 'Privacy & data',
    description: 'Encrypted .pllm export and import.',
  },
  {
    id: 'about',
    label: 'About',
    icon: Info,
    group: 'System',
    description: 'Version, capabilities and honest limits.',
  },
];

const SECTION_IDS = new Set(SETTINGS_SECTIONS.map((s) => s.id));

export function isSettingsSection(id: string): boolean {
  return SECTION_IDS.has(id);
}

export function getSectionMeta(id: string): SettingsSectionMeta {
  return SETTINGS_SECTIONS.find((s) => s.id === id) ?? SETTINGS_SECTIONS[0];
}

function goToSection(id: string) {
  router.navigate(`/app/settings/${id}`);
}

/* ------------------------------ desktop ------------------------------ */

export function SettingsNav({ active }: { active: string }) {
  const groups = [...new Set(SETTINGS_SECTIONS.map((s) => s.group))];
  return (
    <nav aria-label="Settings sections" className="sticky top-0">
      {groups.map((group) => (
        <div key={group} className="mb-4">
          <p className="mb-1.5 px-2 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
            {group}
          </p>
          <ul className="space-y-0.5">
            {SETTINGS_SECTIONS.filter((s) => s.group === group).map((s) => {
              const isActive = s.id === active;
              return (
                <li key={s.id}>
                  <button
                    type="button"
                    onClick={() => goToSection(s.id)}
                    aria-current={isActive ? 'page' : undefined}
                    className={cn(
                      'flex w-full items-center gap-2.5 rounded-lg px-2 py-1.5 text-[13px] font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
                      isActive
                        ? 'bg-muted text-foreground'
                        : 'text-muted-foreground hover:bg-muted/60 hover:text-foreground'
                    )}
                  >
                    <s.icon
                      className={cn(
                        'h-4 w-4 shrink-0',
                        isActive ? 'text-brand-strong' : 'text-muted-foreground'
                      )}
                      aria-hidden
                    />
                    <span className="truncate">{s.label}</span>
                  </button>
                </li>
              );
            })}
          </ul>
        </div>
      ))}
    </nav>
  );
}

/* ------------------------------ mobile ------------------------------- */

export function SettingsTabs({ active }: { active: string }) {
  return (
    <nav
      aria-label="Settings sections"
      className='-mx-4 mb-2 mt-4 overflow-x-auto px-4 pb-2 scrollbar-slim md:hidden'
    >
      <ul className='flex w-max items-center gap-1.5'>
        {SETTINGS_SECTIONS.map((s) => {
          const isActive = s.id === active;
          return (
            <li key={s.id}>
              <button
                type="button"
                onClick={() => goToSection(s.id)}
                aria-current={isActive ? 'page' : undefined}
                className={cn(
                  'inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border px-3 py-1.5 text-xs font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
                  isActive
                    ? 'border-brand-strong bg-brand/15 text-foreground'
                    : 'border-border text-muted-foreground hover:bg-muted/60'
                )}
              >
                <s.icon className="h-3.5 w-3.5" aria-hidden />
                {s.label}
              </button>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
