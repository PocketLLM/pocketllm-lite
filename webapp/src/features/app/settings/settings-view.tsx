'use client';

/**
 * SettingsView — sectioned settings with a sticky desktop nav,
 * scrollable mobile tabs, and one content pane. Every section saves
 * through the live settings object (localStorage + event bus).
 */
import { PageHeader } from '@/features/app/shared/ui';
import { SavedFlash } from './setting-row';
import {
  getSectionMeta,
  isSettingsSection,
  SettingsNav,
  SettingsTabs,
} from './settings-nav';
import { GeneralSettings } from './settings-general';
import { AppearanceSettings } from './settings-appearance';
import { ChatSettings } from './settings-chat';
import { MemorySettings } from './settings-memory';
import { KnowledgeSettings } from './settings-knowledge';
import { ToolsSettings } from './settings-tools';
import { PrivacySettings } from './settings-privacy';
import { NetworkSettings } from './settings-network';
import { StorageSettings } from './settings-storage';
import { BackupSettings } from './settings-backup';
import { AccessibilitySettings } from './settings-accessibility';
import { LanguageSettings } from './settings-language';
import { AboutSettings } from './settings-about';

const SECTION_VIEWS: Record<string, React.ReactNode> = {
  general: <GeneralSettings />,
  appearance: <AppearanceSettings />,
  chat: <ChatSettings />,
  memory: <MemorySettings />,
  knowledge: <KnowledgeSettings />,
  tools: <ToolsSettings />,
  privacy: <PrivacySettings />,
  network: <NetworkSettings />,
  storage: <StorageSettings />,
  backup: <BackupSettings />,
  accessibility: <AccessibilitySettings />,
  language: <LanguageSettings />,
  about: <AboutSettings />,
};

export function SettingsView({ section }: { section: string }) {
  const active = isSettingsSection(section) ? section : 'general';
  const meta = getSectionMeta(active);

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-5xl px-4 pb-24 pt-6 sm:px-6">
        <PageHeader
          title="Settings"
          description="Stored in this browser only — no account, no sync. Changes save as you make them."
          actions={<SavedFlash />}
        />

        <SettingsTabs active={active} />

        <div className="mt-2 flex gap-8">
          <aside className="hidden w-52 shrink-0 md:block">
            <SettingsNav active={active} />
          </aside>
          <div className="min-w-0 flex-1">
            <header className="mb-4">
              <h2 className="flex items-center gap-2 text-[15px] font-semibold">
                <meta.icon className="h-4 w-4 text-brand-strong" aria-hidden />
                {meta.label}
              </h2>
              <p className="mt-0.5 text-[13px] text-muted-foreground">
                {meta.description}
              </p>
            </header>
            {SECTION_VIEWS[active]}
          </div>
        </div>
      </div>
    </div>
  );
}
