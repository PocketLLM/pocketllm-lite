'use client';

/**
 * Memory — the master switch plus extraction controls. When the master
 * is off, nothing is remembered or extracted anywhere in the app.
 */
import { Brain } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Slider } from '@/components/ui/slider';
import { Switch } from '@/components/ui/switch';
import { Section } from '@/features/app/shared/ui';
import { Footnote, SettingRow, SettingRows } from './setting-row';
import { useAppStore } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';

export function MemorySettings() {
  const memory = useAppStore((s) => s.settings.memory);
  const patchSettings = useAppStore((s) => s.patchSettings);

  return (
    <Section
      title="Memory"
      description="Long-lived facts the assistant keeps between chats. Stored locally, never synced."
    >
      <SettingRows>
        <SettingRow
          label="Memory"
          description="Master switch — when off, no memory is used or extracted."
          control={
            <Switch
              checked={memory.enabled}
              onCheckedChange={(v) => patchSettings({ memory: { enabled: v } })}
              aria-label="Memory enabled"
            />
          }
        />
        <SettingRow
          label="Auto-extract"
          description="Pull candidate facts out of conversations automatically after each reply."
          disabled={!memory.enabled}
          control={
            <Switch
              checked={memory.autoExtract}
              onCheckedChange={(v) => patchSettings({ memory: { autoExtract: v } })}
              aria-label="Auto-extract memories"
            />
          }
        />
        <SettingRow
          wide
          label="Memories in prompt"
          description="How many stored memories may be injected into a single prompt."
          disabled={!memory.enabled}
          valueLabel={String(memory.maxMemoriesInPrompt)}
          control={
            <Slider
              value={[memory.maxMemoriesInPrompt]}
              min={1}
              max={20}
              step={1}
              onValueChange={([v]) => patchSettings({ memory: { maxMemoriesInPrompt: v } })}
              aria-label="Memories in prompt"
            />
          }
        />
        <SettingRow
          wide
          label="Storage confidence"
          description={`Only store memories with confidence ≥ ${memory.minConfidence.toFixed(2)}. Higher keeps fewer, better facts.`}
          disabled={!memory.enabled}
          valueLabel={`≥ ${memory.minConfidence.toFixed(2)}`}
          control={
            <Slider
              value={[memory.minConfidence]}
              min={0}
              max={0.95}
              step={0.05}
              onValueChange={([v]) => patchSettings({ memory: { minConfidence: v } })}
              aria-label="Minimum memory confidence"
            />
          }
        />
      </SettingRows>

      <Footnote>
        <span className="inline-flex items-center gap-1.5">
          <Brain className="h-3.5 w-3.5" aria-hidden />
          Review, edit or forget stored facts any time on the Memories page.
        </span>{' '}
        <Button
          variant="link"
          size="sm"
          className="h-auto p-0 text-xs"
          onClick={() => router.navigate('/app/memories')}
        >
          Open Memories
        </Button>
      </Footnote>
    </Section>
  );
}
