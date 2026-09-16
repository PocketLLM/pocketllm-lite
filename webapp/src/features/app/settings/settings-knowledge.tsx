'use client';

/**
 * Knowledge — retrieval defaults (mode, chunk size, top-k) applied to
 * newly imported documents and retrieval previews.
 */
import { useEffect, useState } from 'react';
import { BookOpen } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Slider } from '@/components/ui/slider';
import { Section } from '@/features/app/shared/ui';
import {
  Footnote,
  SettingRow,
  SettingRows,
  SettingsSelect,
} from './setting-row';
import { useAppStore } from '@/lib/store/app-store';
import { router } from '@/lib/core/router';
import type { AppSettings } from '@/lib/types/domain';

export function KnowledgeSettings() {
  const knowledge = useAppStore((s) => s.settings.knowledge);
  const patchSettings = useAppStore((s) => s.patchSettings);

  const [chunkSize, setChunkSize] = useState(String(knowledge.chunkSize));
  useEffect(() => setChunkSize(String(knowledge.chunkSize)), [knowledge.chunkSize]);
  const commitChunkSize = () => {
    const parsed = Math.round(Number(chunkSize));
    const clamped = Number.isFinite(parsed)
      ? Math.min(3000, Math.max(300, parsed))
      : 900;
    if (clamped !== knowledge.chunkSize) {
      patchSettings({ knowledge: { chunkSize: clamped } });
    }
    setChunkSize(String(clamped));
  };

  return (
    <Section
      title="Knowledge"
      description="Defaults for retrieving from your documents. Applies to new imports; existing documents can be re-indexed individually."
    >
      <SettingRows>
        <SettingRow
          label="Retrieval mode"
          description="How chunks are found when you attach documents or search."
          htmlFor="setting-retrieval-mode"
          control={
            <SettingsSelect
              id="setting-retrieval-mode"
              ariaLabel="Retrieval mode"
              value={knowledge.defaultRetrievalMode}
              onValueChange={(v) =>
                patchSettings({
                  knowledge: {
                    defaultRetrievalMode: v as AppSettings['knowledge']['defaultRetrievalMode'],
                  },
                })
              }
              options={[
                {
                  value: 'hybrid',
                  label: 'Hybrid',
                  hint: 'recommended',
                },
                { value: 'lexical', label: 'Lexical' },
                { value: 'semantic', label: 'Semantic' },
              ]}
            />
          }
        />
        <SettingRow
          label="Chunk size"
          description="Characters per chunk (300–3000). Smaller chunks give sharper citations."
          htmlFor="setting-chunk-size"
          control={
            <Input
              id="setting-chunk-size"
              type="number"
              min={300}
              max={3000}
              value={chunkSize}
              onChange={(e) => setChunkSize(e.target.value)}
              onBlur={commitChunkSize}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  commitChunkSize();
                  e.currentTarget.blur();
                }
              }}
              className="w-28"
            />
          }
        />
        <SettingRow
          wide
          label="Results per query (top-k)"
          description="How many document chunks a retrieval returns at most."
          valueLabel={String(knowledge.topK)}
          control={
            <Slider
              value={[knowledge.topK]}
              min={1}
              max={12}
              step={1}
              onValueChange={([v]) => patchSettings({ knowledge: { topK: v } })}
              aria-label="Results per query"
            />
          }
        />
      </SettingRows>

      <Footnote>
        <span className="inline-flex items-center gap-1.5">
          <BookOpen className="h-3.5 w-3.5" aria-hidden />
          Hybrid fuses lexical (BM25) and semantic (local TF-IDF) ranks;
          semantic here means on-device statistics, not a downloaded embedding
          model.
        </span>{' '}
        <Button
          variant="link"
          size="sm"
          className="h-auto p-0 text-xs"
          onClick={() => router.navigate('/app/knowledge')}
        >
          Open Knowledge
        </Button>
      </Footnote>
    </Section>
  );
}
