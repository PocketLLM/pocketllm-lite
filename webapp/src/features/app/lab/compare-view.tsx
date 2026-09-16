'use client';

/**
 * CompareView — one prompt through 2-4 runtime/model combos,
 * side-by-side, with honest metrics (TTFT, duration, tok/s).
 */
import { useMemo, useState } from 'react';
import { Play, Plus, X, Columns3, Save } from 'lucide-react';
import { useAppStore } from '@/lib/store/app-store';
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import { labRunRepo } from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { PageHeader, Section, EmptyState, MetaPill } from '@/features/app/shared/ui';
import { Button } from '@/components/ui/button';
import { MarkdownMessage } from '@/features/app/shared/markdown-message';
import { cn, formatDuration } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type { LabRun, RuntimeId } from '@/lib/types/domain';

interface Lane {
  id: string;
  runtimeId: RuntimeId;
  modelId: string;
  label: string;
}

interface LaneResult {
  content: string;
  streaming: boolean;
  metrics?: LabRun['results'][number]['metrics'];
  error?: string;
}

export function CompareView() {
  const { models } = useAppStore();
  const [prompt, setPrompt] = useState('');
  const [lanes, setLanes] = useState<Lane[]>([]);
  const [results, setResults] = useState<Record<string, LaneResult>>({});
  const [running, setRunning] = useState(false);

  const availableModels = models;

  const canRun = prompt.trim() && lanes.length >= 2 && !running;

  const addLane = () => {
    if (lanes.length >= 4) return;
    const used = new Set(lanes.map((l) => `${l.runtimeId}:${l.modelId}`));
    const next = availableModels.find((m) => !used.has(`${m.runtimeId}:${m.id}`));
    if (!next) {
      toast({ title: 'No more distinct models', description: 'All available models are already in the comparison.' });
      return;
    }
    setLanes((ls) => [
      ...ls,
      {
        id: crypto.randomUUID(),
        runtimeId: next.runtimeId,
        modelId: next.id,
        label: next.label,
      },
    ]);
  };

  const removeLane = (id: string) => {
    setLanes((ls) => ls.filter((l) => l.id !== id));
    setResults((r) => {
      const { [id]: _removed, ...rest } = r;
      void _removed;
      return rest;
    });
  };

  const updateLane = (id: string, patch: Partial<Lane>) =>
    setLanes((ls) => ls.map((l) => (l.id === id ? { ...l, ...patch } : l)));

  const runAll = async () => {
    if (!canRun) return;
    setRunning(true);
    setResults({});
    // Initialize all lanes as streaming.
    const initial: Record<string, LaneResult> = {};
    for (const l of lanes) initial[l.id] = { content: '', streaming: true };
    setResults(initial);

    await Promise.all(
      lanes.map(async (lane) => {
        try {
          const result = await inferenceRouter.generate(
            lane.runtimeId,
            [{ role: 'user', content: prompt }],
            {
              onToken: (delta) =>
                setResults((r) => ({
                  ...r,
                  [lane.id]: { ...r[lane.id], content: (r[lane.id]?.content ?? '') + delta },
                })),
            }
          );
          setResults((r) => ({
            ...r,
            [lane.id]: { content: result.content, streaming: false, metrics: result.metrics },
          }));
        } catch (err) {
          setResults((r) => ({
            ...r,
            [lane.id]: {
              content: r[lane.id]?.content ?? '',
              streaming: false,
              error: err instanceof Error ? err.message : 'Failed',
            },
          }));
        }
      })
    );
    setRunning(false);
  };

  const saveComparison = async () => {
    const finished = lanes.filter((l) => results[l.id]?.content);
    if (finished.length < 2) return;
    await labRunRepo.put({
      id: crypto.randomUUID(),
      kind: 'comparison',
      prompt,
      results: finished.map((l) => ({
        runtimeId: l.runtimeId,
        modelId: l.modelId,
        content: results[l.id].content,
        metrics: results[l.id].metrics,
      })),
      createdAt: Date.now(),
    });
    bus.emit('labRuns:changed');
    toast({ title: 'Comparison saved', description: 'Find it again from the Activity page.' });
  };

  const hasResults = useMemo(
    () => Object.values(results).some((r) => r.content),
    [results]
  );

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-6xl px-4 py-6 pb-24 sm:px-6">
        <PageHeader
          title="Model comparison"
          description="One prompt, two to four runtimes, side by side. Metrics are measured, never invented."
          actions={
            <>
              <Button variant="outline" onClick={() => void saveComparison()} disabled={!hasResults || running}>
                <Save className="h-4 w-4" /> Save
              </Button>
              <Button onClick={() => void runAll()} disabled={!canRun}>
                <Play className="h-4 w-4" /> Run all
              </Button>
            </>
          }
        />

        <Section title="Prompt">
          <textarea
            value={prompt}
            onChange={(e) => setPrompt(e.target.value)}
            placeholder="The same prompt goes to every selected model…"
            aria-label="Comparison prompt"
            className="min-h-[80px] w-full resize-y rounded-lg border border-border bg-background p-3 text-sm outline-none focus:border-brand-strong"
          />
        </Section>

        <Section
          title="Models"
          description="Select 2-4 runtime/model combinations."
          actions={
            <Button variant="outline" size="sm" onClick={addLane} disabled={lanes.length >= 4}>
              <Plus className="h-3.5 w-3.5" /> Add lane
            </Button>
          }
        >
          {lanes.length === 0 ? (
            <EmptyState
              icon={Columns3}
              title="No lanes yet"
              description="Add at least two runtime/model lanes to compare."
              action={
                <Button size="sm" onClick={addLane}>
                  <Plus className="h-4 w-4" /> Add lane
                </Button>
              }
            />
          ) : (
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
              {lanes.map((lane) => (
                <div key={lane.id} className="rounded-xl border border-border p-3">
                  <div className="mb-2 flex items-center justify-between">
                    <span className="text-xs font-semibold text-muted-foreground">
                      Lane {lanes.indexOf(lane) + 1}
                    </span>
                    <button
                      onClick={() => removeLane(lane.id)}
                      className="rounded p-1 text-muted-foreground hover:bg-muted hover:text-destructive"
                      aria-label="Remove lane"
                    >
                      <X className="h-3.5 w-3.5" />
                    </button>
                  </div>
                  <select
                    value={`${lane.runtimeId}:${lane.modelId}`}
                    onChange={(e) => {
                      const [runtimeId, modelId] = e.target.value.split(':');
                      const model = availableModels.find(
                        (m) => m.runtimeId === runtimeId && m.id === modelId
                      );
                      updateLane(lane.id, {
                        runtimeId: runtimeId as RuntimeId,
                        modelId,
                        label: model?.label ?? modelId,
                      });
                    }}
                    aria-label="Model for this lane"
                    className="w-full rounded-lg border border-border bg-background p-2 text-[13px]"
                  >
                    {['assist', 'ollama', 'openai', 'mock'].map((rt) => {
                      const opts = availableModels.filter((m) => m.runtimeId === rt);
                      if (!opts.length) return null;
                      return (
                        <optgroup key={rt} label={rt === 'assist' ? 'Assist' : rt === 'ollama' ? 'Ollama' : rt === 'openai' ? 'Endpoint' : 'Sandbox'}>
                          {opts.map((m) => (
                            <option key={m.id} value={`${m.runtimeId}:${m.id}`}>
                              {m.label}
                            </option>
                          ))}
                        </optgroup>
                      );
                    })}
                  </select>
                </div>
              ))}
            </div>
          )}
        </Section>

        {hasResults && (
          <div className={cn('grid gap-4', lanes.length >= 3 ? 'lg:grid-cols-3 xl:grid-cols-4' : 'md:grid-cols-2')}>
            {lanes.map((lane) => {
              const r = results[lane.id];
              if (!r) return null;
              return (
                <Section key={lane.id} title={lane.label} className="min-w-0">
                  <div className="mb-2 flex flex-wrap gap-1.5">
                    {r.metrics?.ttftMs != null && (
                      <MetaPill>TTFT {Math.round(r.metrics.ttftMs)}ms</MetaPill>
                    )}
                    {r.metrics?.durationMs != null && (
                      <MetaPill>{formatDuration(r.metrics.durationMs)}</MetaPill>
                    )}
                    {r.metrics?.tokensPerSecond != null && (
                      <MetaPill tone="accent">{r.metrics.tokensPerSecond} tok/s</MetaPill>
                    )}
                    {r.streaming && <MetaPill tone="accent">streaming…</MetaPill>}
                  </div>
                  {r.error ? (
                    <p className="rounded-lg border border-destructive/40 bg-destructive/10 p-2 text-[13px] text-destructive">
                      {r.error}
                    </p>
                  ) : (
                    <div className="max-h-[420px] overflow-y-auto scrollbar-slim pr-1 text-[13px]">
                      <MarkdownMessage content={r.content} />
                    </div>
                  )}
                </Section>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
