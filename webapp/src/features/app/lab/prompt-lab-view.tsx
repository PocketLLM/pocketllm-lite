'use client';

/**
 * PromptLabView — split-view prompt experimentation.
 *
 * Left: prompt + optional system prompt + generation parameters.
 * Right: response with metrics and the composed-system layer breakdown
 * (debugging the exact prompt composition order).
 * Runs persist locally and can be reopened.
 */
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Play,
  Square,
  Save,
  History,
  Trash2,
  Clock,
  Gauge,
  Layers,
  Loader2,
} from 'lucide-react';
import { useAppStore } from '@/lib/store/app-store';
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import { promptComposer } from '@/lib/services/prompt-composer';
import { labRunRepo } from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { router } from '@/lib/core/router';
import { PageHeader, Section, EmptyState, MetaPill } from '@/features/app/shared/ui';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Slider } from '@/components/ui/slider';
import { MarkdownMessage } from '@/features/app/shared/markdown-message';
import { cn, formatDuration, formatRelativeTime } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type { LabRun } from '@/lib/types/domain';

export function PromptLabView() {
  const { models } = useAppStore();
  const [prompt, setPrompt] = useState('');
  const [systemPrompt, setSystemPrompt] = useState('');
  const [temperature, setTemperature] = useState(0.7);
  const [topP, setTopP] = useState(0.9);
  const [maxTokens, setMaxTokens] = useState(1024);
  const [runtimeId, setRuntimeId] = useState('assist');
  const [modelId, setModelId] = useState('pocketllm-assist');
  const [response, setResponse] = useState('');
  const [metrics, setMetrics] = useState<LabRun['results'][number]['metrics']>();
  const [running, setRunning] = useState(false);
  const [runs, setRuns] = useState<LabRun[]>([]);
  const abortRef = useRef<AbortController | null>(null);

  const runtimeModels = useMemo(
    () => models.filter((m) => m.runtimeId === runtimeId),
    [models, runtimeId]
  );

  const loadRuns = useCallback(async () => {
    const all = await labRunRepo.getAll();
    setRuns(all.filter((r) => r.kind === 'prompt').sort((a, b) => b.createdAt - a.createdAt));
  }, []);

  useEffect(() => {
    void loadRuns();
  }, [loadRuns]);

  const layerBreakdown = useMemo(
    () =>
      promptComposer.describeLayers({
        persona: null,
        skills: [],
        memories: [],
        documentContext: systemPrompt ? [{ name: 'Custom system prompt', excerpt: systemPrompt }] : [],
      }),
    [systemPrompt]
  );

  const run = async () => {
    if (!prompt.trim() || running) return;
    setRunning(true);
    setResponse('');
    setMetrics(undefined);
    const abort = new AbortController();
    abortRef.current = abort;
    try {
      const turns = [
        ...(systemPrompt.trim() ? [{ role: 'system' as const, content: systemPrompt }] : []),
        { role: 'user' as const, content: prompt },
      ];
      const result = await inferenceRouter.generate(runtimeId as LabRun['results'][number]['runtimeId'], turns, {
        signal: abort.signal,
        settings: { temperature, topP, maxTokens },
        onToken: (delta) => setResponse((v) => v + delta),
      });
      setMetrics(result.metrics);
    } catch (err) {
      if (!abort.signal.aborted) {
        toast({
          title: 'Run failed',
          description: err instanceof Error ? err.message : 'Unknown error',
          variant: 'destructive',
        });
      } else {
        setMetrics((m) => m ?? { durationMs: 0 });
      }
    } finally {
      setRunning(false);
      abortRef.current = null;
    }
  };

  const stop = () => abortRef.current?.abort();

  const saveRun = async () => {
    if (!response) return;
    await labRunRepo.put({
      id: crypto.randomUUID(),
      kind: 'prompt',
      prompt,
      systemPrompt: systemPrompt || undefined,
      parameters: { temperature, topP, maxTokens },
      results: [
        { runtimeId: runtimeId as LabRun['results'][number]['runtimeId'], modelId, content: response, metrics },
      ],
      createdAt: Date.now(),
    });
    bus.emit('labRuns:changed');
    await loadRuns();
    toast({ title: 'Run saved', description: 'Reopen it from the run history below.' });
  };

  const openRun = (run: LabRun) => {
    setPrompt(run.prompt);
    setSystemPrompt(run.systemPrompt ?? '');
    if (run.parameters) {
      setTemperature(run.parameters.temperature ?? 0.7);
      setTopP(run.parameters.topP ?? 0.9);
      setMaxTokens(run.parameters.maxTokens ?? 1024);
    }
    const r = run.results[0];
    if (r) {
      setRuntimeId(r.runtimeId);
      setModelId(r.modelId);
      setResponse(r.content);
      setMetrics(r.metrics);
    }
  };

  const deleteRun = async (id: string) => {
    await labRunRepo.delete(id);
    await loadRuns();
  };

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-6xl px-4 py-6 pb-24 sm:px-6">
        <PageHeader
          title="Prompt Lab"
          description="Tune parameters and inspect the exact composition sent to the model."
          actions={
            <>
              {running ? (
                <Button variant="destructive" onClick={stop}>
                  <Square className="h-4 w-4" /> Stop
                </Button>
              ) : (
                <Button onClick={() => void run()} disabled={!prompt.trim()}>
                  <Play className="h-4 w-4" /> Run
                </Button>
              )}
              <Button variant="outline" onClick={() => void saveRun()} disabled={!response || running}>
                <Save className="h-4 w-4" /> Save
              </Button>
            </>
          }
        />

        <div className="grid gap-4 lg:grid-cols-2">
          {/* Left: inputs */}
          <div className="space-y-4">
            <Section title="Prompt" description="The user message sent to the model.">
              <textarea
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                placeholder="Write the prompt to test…"
                aria-label="Prompt"
                className="min-h-[120px] w-full resize-y rounded-lg border border-border bg-background p-3 text-sm outline-none focus:border-brand-strong"
              />
            </Section>

            <Section title="System prompt (optional)" description="Replaces the default composition layers.">
              <textarea
                value={systemPrompt}
                onChange={(e) => setSystemPrompt(e.target.value)}
                placeholder="e.g. You are a terse technical assistant…"
                aria-label="System prompt"
                className="min-h-[80px] w-full resize-y rounded-lg border border-border bg-background p-3 text-sm outline-none focus:border-brand-strong"
              />
            </Section>

            <Section title="Runtime & model">
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1.5">
                  <Label htmlFor="lab-runtime">Runtime</Label>
                  <select
                    id="lab-runtime"
                    value={runtimeId}
                    onChange={(e) => {
                      setRuntimeId(e.target.value);
                      const first = models.find((m) => m.runtimeId === e.target.value);
                      setModelId(first?.id ?? '');
                    }}
                    className="w-full rounded-lg border border-border bg-background p-2 text-sm"
                  >
                    <option value="assist">PocketLLM Assist</option>
                    <option value="ollama">Ollama</option>
                    <option value="openai">OpenAI-compatible</option>
                    <option value="mock">Offline Sandbox</option>
                  </select>
                </div>
                <div className="space-y-1.5">
                  <Label htmlFor="lab-model">Model</Label>
                  <select
                    id="lab-model"
                    value={modelId}
                    onChange={(e) => setModelId(e.target.value)}
                    className="w-full rounded-lg border border-border bg-background p-2 text-sm"
                  >
                    {runtimeModels.map((m) => (
                      <option key={m.id} value={m.id}>
                        {m.label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </Section>

            <Section title="Parameters">
              <div className="space-y-4">
                <div>
                  <div className="mb-2 flex items-center justify-between">
                    <Label>Temperature</Label>
                    <span className="font-mono text-xs text-muted-foreground">{temperature.toFixed(2)}</span>
                  </div>
                  <Slider
                    value={[temperature]}
                    min={0}
                    max={2}
                    step={0.05}
                    onValueChange={([v]) => setTemperature(v)}
                    aria-label="Temperature"
                  />
                </div>
                <div>
                  <div className="mb-2 flex items-center justify-between">
                    <Label>Top P</Label>
                    <span className="font-mono text-xs text-muted-foreground">{topP.toFixed(2)}</span>
                  </div>
                  <Slider
                    value={[topP]}
                    min={0.05}
                    max={1}
                    step={0.05}
                    onValueChange={([v]) => setTopP(v)}
                    aria-label="Top P"
                  />
                </div>
                <div>
                  <div className="mb-2 flex items-center justify-between">
                    <Label>Max tokens</Label>
                    <span className="font-mono text-xs text-muted-foreground">{maxTokens}</span>
                  </div>
                  <Slider
                    value={[maxTokens]}
                    min={128}
                    max={4096}
                    step={128}
                    onValueChange={([v]) => setMaxTokens(v)}
                    aria-label="Max tokens"
                  />
                </div>
              </div>
            </Section>

            <Section title="Composition preview" description="Layers that would compose the system prompt when no custom system prompt is set.">
              <ul className="space-y-1.5 text-[13px]">
                {layerBreakdown.map((l) => (
                  <li key={l.layer} className="flex items-center justify-between">
                    <span className={cn(l.present ? 'text-foreground' : 'text-muted-foreground/50')}>
                      <Layers className="mr-1.5 inline h-3 w-3" />
                      {l.layer}
                    </span>
                    <span className="font-mono text-[11px] text-muted-foreground">
                      {l.present ? `${l.chars} chars` : '—'}
                    </span>
                  </li>
                ))}
              </ul>
            </Section>
          </div>

          {/* Right: response */}
          <div className="space-y-4">
            <Section
              title="Response"
              actions={
                metrics && (
                  <div className="flex flex-wrap gap-1.5">
                    <MetaPill>
                      <Clock className="h-3 w-3" />
                      {metrics.ttftMs != null ? `${Math.round(metrics.ttftMs)}ms TTFT` : 'TTFT n/a'}
                    </MetaPill>
                    <MetaPill>
                      <Gauge className="h-3 w-3" />
                      {metrics.durationMs != null ? formatDuration(metrics.durationMs) : '—'}
                    </MetaPill>
                    {metrics.tokensPerSecond != null && (
                      <MetaPill tone="accent">{metrics.tokensPerSecond} tok/s</MetaPill>
                    )}
                  </div>
                )
              }
            >
              {running && !response ? (
                <div className="flex items-center gap-2 py-8 text-sm text-muted-foreground">
                  <Loader2 className="h-4 w-4 animate-spin" /> Running…
                </div>
              ) : response ? (
                <div className="max-h-[480px] overflow-y-auto scrollbar-slim pr-1">
                  <MarkdownMessage content={response} />
                </div>
              ) : (
                <p className="py-8 text-center text-sm text-muted-foreground">
                  Run a prompt to see the response, metrics and token statistics here.
                </p>
              )}
            </Section>

            <Section title="Run history" description="Saved locally — click to reopen a run.">
              {runs.length === 0 ? (
                <EmptyState
                  icon={History}
                  title="No saved runs"
                  description="Save a run to compare parameter changes later."
                />
              ) : (
                <ul className="max-h-72 space-y-1.5 overflow-y-auto scrollbar-slim">
                  {runs.map((r) => (
                    <li key={r.id} className="flex items-center gap-2 rounded-lg border border-border p-2.5">
                      <button
                        onClick={() => openRun(r)}
                        className="min-w-0 flex-1 text-left"
                        aria-label={`Reopen run: ${r.prompt.slice(0, 40)}`}
                      >
                        <span className="block truncate text-[13px]">{r.prompt}</span>
                        <span className="text-[11px] text-muted-foreground">
                          {formatRelativeTime(r.createdAt)} · temp {r.parameters?.temperature?.toFixed(2) ?? '—'}
                        </span>
                      </button>
                      <button
                        onClick={() => void deleteRun(r.id)}
                        className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-destructive"
                        aria-label="Delete run"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </Section>
          </div>
        </div>
      </div>
    </div>
  );
}
