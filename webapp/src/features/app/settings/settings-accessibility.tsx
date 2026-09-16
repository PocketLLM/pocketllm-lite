'use client';

/**
 * Accessibility — reduce motion, a pointer to text sizing, and the
 * keyboard reference card.
 */
import { Keyboard, MoveRight, PersonStanding } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Section } from '@/features/app/shared/ui';
import { SettingRow, SettingRows } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';

const SHORTCUTS: Array<{ keys: string[]; label: string }> = [
  { keys: ['Enter'], label: 'Send the message' },
  { keys: ['Shift', 'Enter'], label: 'New line in the composer' },
  { keys: ['Esc'], label: 'Close dialogs and menus' },
];

export function AccessibilitySettings() {
  const reduceMotion = useAppStore((s) => s.settings.general.reduceMotion);
  const patchSettings = useAppStore((s) => s.patchSettings);

  return (
    <div className="space-y-6">
      <Section
        title="Accessibility"
        description="Motion and sizing. Your OS-level reduced-motion setting is always respected on top of anything here."
      >
        <SettingRows>
          <SettingRow
            label="Reduce motion"
            description="Minimizes animations beyond the OS setting."
            control={
              <Switch
                checked={reduceMotion}
                onCheckedChange={(v) => patchSettings({ general: { reduceMotion: v } })}
                aria-label="Reduce motion"
              />
            }
          />
        </SettingRows>
      </Section>

      <Section
        title="Text size"
        description="Three steps that scale the whole app — including this page."
      >
        <div className="flex flex-wrap items-center justify-between gap-3">
          <p className="flex items-center gap-2 text-[13px] text-muted-foreground">
            <PersonStanding className="h-4 w-4" aria-hidden />
            Small, Default and Large live in Appearance.
          </p>
          <Button
            variant="outline"
            onClick={() => router.navigate('/app/settings/appearance')}
          >
            Open Appearance
            <MoveRight aria-hidden />
          </Button>
        </div>
      </Section>

      <Section title="Keyboard" description="Documented shortcuts across the app.">
        <ul className="divide-y divide-border">
          {SHORTCUTS.map((s) => (
            <li
              key={s.label}
              className="flex items-center justify-between gap-4 py-2.5"
            >
              <span className="text-[13px]">{s.label}</span>
              <span className="flex shrink-0 items-center gap-1">
                <Keyboard className="h-3.5 w-3.5 text-muted-foreground" aria-hidden />
                {s.keys.map((k, i) => (
                  <span key={i}>
                    <kbd className="rounded-md border border-border bg-muted px-1.5 py-0.5 font-mono text-[11px] text-muted-foreground">
                      {k}
                    </kbd>
                    {i < s.keys.length - 1 && (
                      <span className="mx-0.5 text-muted-foreground">+</span>
                    )}
                  </span>
                ))}
              </span>
            </li>
          ))}
        </ul>
      </Section>
    </div>
  );
}
