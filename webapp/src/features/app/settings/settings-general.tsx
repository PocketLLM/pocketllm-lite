'use client';

/**
 * General — display name, send-on-enter, compact mode.
 */
import { useEffect, useState } from 'react';
import { Input } from '@/components/ui/input';
import { Switch } from '@/components/ui/switch';
import { Section } from '@/features/app/shared/ui';
import { SettingRow, SettingRows } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';

export function GeneralSettings() {
  const general = useAppStore((s) => s.settings.general);
  const patchSettings = useAppStore((s) => s.patchSettings);

  const [name, setName] = useState(general.displayName);
  // Stay in sync if settings change elsewhere (e.g. a reset).
  useEffect(() => setName(general.displayName), [general.displayName]);

  const commitName = () => {
    const trimmed = name.trim();
    if (trimmed !== general.displayName) {
      patchSettings({ general: { displayName: trimmed } });
    }
  };

  return (
    <Section
      title="General"
      description="Identity and basic behaviour. Everything saves immediately."
    >
      <SettingRows>
        <SettingRow
          label="Display name"
          description="Used for greetings. Keep it empty for no name at all."
          htmlFor="setting-display-name"
          control={
            <Input
              id="setting-display-name"
              value={name}
              placeholder="What should PocketLLM call you?"
              maxLength={60}
              onChange={(e) => setName(e.target.value)}
              onBlur={commitName}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  commitName();
                  e.currentTarget.blur();
                }
              }}
              className="w-full sm:w-[240px]"
            />
          }
        />
        <SettingRow
          label="Send on Enter"
          description="Pressing Enter sends the message; Shift+Enter adds a newline. Turn off if you prefer Ctrl+Enter-style sending."
          control={
            <Switch
              checked={general.sendOnEnter}
              onCheckedChange={(v) => patchSettings({ general: { sendOnEnter: v } })}
              aria-label="Send on Enter"
            />
          }
        />
        <SettingRow
          label="Compact mode"
          description="Denser message spacing."
          control={
            <Switch
              checked={general.compactMode}
              onCheckedChange={(v) => patchSettings({ general: { compactMode: v } })}
              aria-label="Compact mode"
            />
          }
        />
      </SettingRows>
    </Section>
  );
}
