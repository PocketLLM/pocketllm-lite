'use client';

/**
 * Appearance — theme (via next-themes + persisted setting), text scale,
 * accent (honest: only sandy ships) and a live preview card.
 */
import { Monitor, Moon, Sun } from 'lucide-react';
import { useTheme } from 'next-themes';
import { Button } from '@/components/ui/button';
import { Section } from '@/features/app/shared/ui';
import { SettingRow, SettingRows, SettingsSelect } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';
import type { AppSettings } from '@/lib/types/domain';

const THEME_OPTIONS: Array<{
  value: AppSettings['appearance']['theme'];
  label: string;
  icon: React.ComponentType<{ className?: string }>;
}> = [
  { value: 'light', label: 'Light', icon: Sun },
  { value: 'dark', label: 'Dark', icon: Moon },
  { value: 'system', label: 'System', icon: Monitor },
];

export function AppearanceSettings() {
  const appearance = useAppStore((s) => s.settings.appearance);
  const patchSettings = useAppStore((s) => s.patchSettings);
  const { setTheme } = useTheme();

  const applyTheme = (value: string) => {
    // next-themes applies it instantly; the setting keeps it across boots.
    setTheme(value);
    patchSettings({ appearance: { theme: value as AppSettings['appearance']['theme'] } });
  };

  return (
    <Section
      title="Appearance"
      description="Theme, text size and accent. Changes apply immediately and save locally."
    >
      <SettingRows>
        <SettingRow
          label="Theme"
          description="Light, dark, or follow your system. System uses your OS preference."
          control={
            <div
              role="radiogroup"
              aria-label="Theme"
              className="flex w-full gap-1.5 sm:w-auto"
            >
              {THEME_OPTIONS.map((t) => {
                const active = appearance.theme === t.value;
                return (
                  <button
                    key={t.value}
                    type="button"
                    role="radio"
                    aria-checked={active}
                    onClick={() => applyTheme(t.value)}
                    className={`inline-flex flex-1 items-center justify-center gap-1.5 rounded-lg border px-3 py-1.5 text-xs font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring sm:flex-none ${
                      active
                        ? 'border-brand-strong bg-brand/15 text-foreground'
                        : 'border-border text-muted-foreground hover:bg-muted/60'
                    }`}
                  >
                    <t.icon className="h-3.5 w-3.5" aria-hidden />
                    {t.label}
                  </button>
                );
              })}
            </div>
          }
        />
        <SettingRow
          label="Font size"
          description="Scales the entire app — 15, 16 or 17.5 px base."
          htmlFor="setting-font-size"
          control={
            <SettingsSelect
              id="setting-font-size"
              ariaLabel="Font size"
              value={appearance.fontSize}
              onValueChange={(v) =>
                patchSettings({
                  appearance: { fontSize: v as AppSettings['appearance']['fontSize'] },
                })
              }
              options={[
                { value: 'sm', label: 'Small', hint: '15px' },
                { value: 'md', label: 'Default', hint: '16px' },
                { value: 'lg', label: 'Large', hint: '17.5px' },
              ]}
            />
          }
        />
        <SettingRow
          label="Accent"
          description="Sandy is the shipped brand accent — the other palettes are future work and can't be selected yet."
          htmlFor="setting-accent"
          control={
            <SettingsSelect
              id="setting-accent"
              ariaLabel="Accent colour"
              value={appearance.accent}
              onValueChange={(v) =>
                patchSettings({
                  appearance: { accent: v as AppSettings['appearance']['accent'] },
                })
              }
              options={[
                { value: 'sandy', label: 'Sandy yellow' },
                { value: 'amber', label: 'Amber', disabled: true },
                { value: 'rose', label: 'Rose', disabled: true },
                { value: 'mint', label: 'Mint', disabled: true },
              ]}
            />
          }
        />
      </SettingRows>

      <div className="mt-5">
        <h3 className="mb-2 text-[13px] font-semibold">Live preview</h3>
        <div
          className="rounded-xl border border-border bg-background p-4"
          aria-label="Appearance preview"
        >
          <div className="flex justify-end">
            <div className="max-w-[85%] rounded-2xl bg-primary px-4 py-2 text-[15px] leading-relaxed text-primary-foreground">
              Summarize this document
            </div>
          </div>
          <div className="mt-2 flex">
            <div className="max-w-[85%] rounded-2xl border border-border bg-card px-4 py-2 text-[15px] leading-relaxed">
              Here&apos;s the short version — three findings, one caveat.
            </div>
          </div>
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <Button size="sm">Send</Button>
            <Button size="sm" variant="outline">
              Cancel
            </Button>
            <span className="inline-flex items-center rounded-full bg-brand px-2 py-0.5 text-[10px] font-semibold text-brand-foreground">
              accent
            </span>
          </div>
        </div>
      </div>
    </Section>
  );
}
