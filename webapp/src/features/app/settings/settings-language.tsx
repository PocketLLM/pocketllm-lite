'use client';

/**
 * Language — locale picker. Honest about what it does today.
 */
import { Section } from '@/features/app/shared/ui';
import { Footnote, SettingRow, SettingRows, SettingsSelect } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';

const LOCALES = [
  { value: 'en', label: 'English' },
  { value: 'hi', label: 'हिन्दी (Hindi)' },
  { value: 'es', label: 'Español (Spanish)' },
  { value: 'fr', label: 'Français (French)' },
  { value: 'de', label: 'Deutsch (German)' },
  { value: 'ja', label: '日本語 (Japanese)' },
];

export function LanguageSettings() {
  const locale = useAppStore((s) => s.settings.language.locale);
  const patchSettings = useAppStore((s) => s.patchSettings);

  const value = LOCALES.some((l) => l.value === locale) ? locale : 'en';

  return (
    <Section
      title="Language"
      description="Interface translation is English; this controls date and number formatting now. Full localization ships with the localization milestone."
    >
      <SettingRows>
        <SettingRow
          label="Locale"
          description="Used for dates, times and number formatting across the app."
          htmlFor="setting-locale"
          control={
            <SettingsSelect
              id="setting-locale"
              ariaLabel="Locale"
              value={value}
              onValueChange={(v) => patchSettings({ language: { locale: v } })}
              options={LOCALES}
            />
          }
        />
      </SettingRows>
      <Footnote>
        Try it: today&apos;s date reads{' '}
        <span className="font-mono">
          {new Intl.DateTimeFormat(value).format(new Date())}
        </span>{' '}
        in this locale.
      </Footnote>
    </Section>
  );
}
