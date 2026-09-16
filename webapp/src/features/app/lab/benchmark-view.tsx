'use client';

/**
 * BenchmarkView — runs a fixed set of prompts against one runtime and
 * reports measured averages (TTFT, throughput, total time). Metrics
 * are real measurements; nothing is estimated or invented.
 */
import { useState } from 'react';
import { Play, Gauge, Timer, Zap, Save, Loader2 } from 'lucide-react';
import { useAppStore } from '@/lib/store/app-store';
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import { labRunRepo } from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { PageHeader, Section, MetaPill } from '@/features/app/shared/ui';
import { Button } from '@/components/ui/button';
import { formatDuration } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type { LabRun, RuntimeId } from '@/lib/types/domain';

/** Standard benchmark prompts — fixed so runs are comparable. */
const BENCH_PROMPTS = [
  {
    id: 'recall',
    label: 'Short recall',
    prompt: 'Count from 1 to 20, one number per line, nothing else.',
  },
  {
    id: 'story',
    label: 'Sustained generation',
    prompt: 'Write exactly a 100-word story about a robot learning to paint. No preamble.',
  },
  {
    id: 'explain',
    label: 'Reasoned explanation',
    prompt: 'Explain photosynthesis in exactly 3 sentences for a 10-year-old.',
  },
];

interface BenchRow {
  id: string;
  label: string;
  ttftMs?: number;
  durationMs?: number;
  tokensPerSecond?: number;
  status: 'pending' | 'running' | 'done' | 'error';
  error?: string;
}

export function BenchmarkView() {
  const { models } = useAppStore();
  const [runtimeId, setRuntimeId] = useState<RuntimeId>('assist');
  const [modelId, setModelId] = useState('pocketllm-assist');
  const [rows, setRows] = useState<BenchRow[]>([]);
  const [running, setRunning] = useState(false);
  const [avg, setAvg] = useState<{ ttft: number; tps: number; total: number } | null>(null);

  const runtimeModels = models.filter((m) => m.runtimeId === runtimeId);

  const run = async () => {
    if (running) return;
    setRunning(true);
    setAvg(null);
    setRows(BENCH_PROMPTS.map((p) => ({ ...p, status: 'pending' })));
    const totalStart = performance.now();
    const finished: BenchRow[] = [];

    for (const bench of BENCH_PROMPTS) {
      setRows((rs) => rs.map((r) => (r.id === bench.id ? { ...r, status: 'running' } : r)));
      const row: BenchRow = { ...bench, status: 'running' };
      try {
        const result = await inferenceRouter.generate(runtimeId, [
          { role: 'user', content: bench.prompt },
        ], {});
        row.status = 'done';
        row.ttftMs = result.metrics.ttftMs;
        row.durationMs = result.metrics.durationMs;
        row.tokensPerSecond = result.metrics.tokensPerSecond;
      } catch (err) {
        row.status = 'error';
        row.error = err instanceof Error ? err.message : 'Failed';
      }
      finished.push(row);
      setRows((rs) => rs.map((r) => (r.id === bench.id ? row : r)));
    }

    const done = finished.filter((r) => r.status === 'done');
    if (done.length > 0) {
      setAvg({
        ttft: Math.round(done.reduce((s, r) => s + (r.ttftMs ?? 0), 0) / done.length),
        tps: Math.round(done.reduce((s, r) => s + (r.tokensPerSecond ?? 0), 0) / done.length),
        total: Math.round(performance.now() - totalStart),
      });
    }
    setRunning(false);
  };

  const save = async () => {
    const done = rows.filter((r) => r.status === 'done');
    if (!done.length) return;
    await labRunRepo.put({
      id: crypto.randomUUID(),
      kind: 'benchmark',
      prompt: `Benchmark · ${modelId} · ${done.length}/${BENCH_PROMPTS.length} prompts`,
      results: done.map((r) => ({
        runtimeId,
        modelId,
        content: r.label,
        metrics: {
          ttftMs: r.ttftMs,
          durationMs: r.durationMs,
          tokensPerSecond: r.tokensPerSecond,
        },
      })),
      createdAt: Date.now(),
    });
    bus.emit('labRuns:changed');
    toast({ title: 'Benchmark saved', description: 'Recorded in the local lab history.' });
  };

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 py-6 pb-24 sm:px-6">
        <PageHeader
          title="Benchmark"
          description="Three fixed prompts, measured on this device. Numbers come from actual runs — no estimates."
          actions={
            <>
              <Button variant="outline" onClick={() => void save()} disabled={!rows.some((r) => r.status === 'done') || running}>
                <Save className="h-4 w-4" /> Save
              </Button>
              <Button onClick={() => void run()} disabled={running}>
                {running ? <Loader2 className="h-4 w-4 animate-spin" /> : <Play className="h-4 w-4" />}
                {running ? 'Running…' : 'Run benchmark'}
              </Button>
            </>
          }
        />

        <Section title="Target">
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label htmlFor="bench-runtime" className="text-[13px] font-medium">Runtime</label>
              <select
                id="bench-runtime"
                value={runtimeId}
                onChange={(e) => {
                  setRuntimeId(e.target.value as RuntimeId);
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
              <label htmlFor="bench-model" className="text-[13px] font-medium">Model</label>
              <select
                id="bench-model"
                value={modelId}
                onChange={(e) => setModelId(e.target.value)}
                className="w-full rounded-lg border border-border bg-background p-2 text-sm"
              >
                {runtimeModels.map((m) => (
                  <option key={m.id} value={m.id}>{m.label}</option>
                ))}
              </select>
            </div>
          </div>
        </Section>

        {rows.length > 0 && (
          <Section title="Results">
            <ul className="space-y-2">
              {rows.map((r) => (
                <li
                  key={r.id}
                  className="flex flex-wrap items-center gap-x-4 gap-y-1 rounded-xl border border-border p-3 text-[13px]"
                >
                  <span className="min-w-40 flex-1 font-medium">{r.label}</span>
                  {r.status === 'running' && (
                    <span className="flex items-center gap-1.5 text-muted-foreground">
                      <Loader2 className="h-3.5 w-3.5 animate-spin" /> running…
                    </span>
                  )}
                  {r.status === 'pending' && <span className="text-muted-foreground/50">pending</span>}
                  {r.status === 'error' && <span className="text-destructive">{r.error}</span>}
                  {r.status === 'done' && (
                    <>
                      <span className="flex items-center gap-1 text-muted-foreground">
                        <Timer className="h-3.5 w-3.5" />
                        TTFT {r.ttftMs != null ? `${Math.round(r.ttftMs)}ms` : '—'}
                      </span>
                      <span className="flex items-center gap-1 text-muted-foreground">
                        <Gauge className="h-3.5 w-3.5" />
                        {r.durationMs != null ? formatDuration(r.durationMs) : '—'}
                      </span>
                      <span className="flex items-center gap-1 text-muted-foreground">
                        <Zap className="h-3.5 w-3.5" />
                        {r.tokensPerSecond != null ? `${r.tokensPerSecond} tok/s` : '—'}
                      </span>
                    </>
                  )}
                </li>
              ))}
            </ul>

            {avg && (
              <div className="mt-4 grid grid-cols-3 gap-3">
                <StatCard label="Avg TTFT" value={`${avg.tps >= 0 ? avg.ttft : '—'}ms`} hint="time to first token" />
                <StatCard label="Avg throughput" value={`${avg.tps} tok/s`} hint="measured" />
                <StatCard label="Total wall time" value={formatDuration(avg.total)} hint="all prompts" />
              </div>
            )}
          </Section>
        )}

        <p className="mt-4 text-center text-[11px] text-muted-foreground">
          Benchmarks measure the full path (network + model) on this device and browser — treat them as
          your-machine numbers, not universal specs.
        </p>
      </div>
    </div>
  );
}

function StatCard({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div className="rounded-xl border border-border bg-card p-4 text-center">
      <p className="text-[11px] font-medium uppercase tracking-wide text-muted-foreground">{label}</p>
      <p className="mt-1 font-display text-xl font-semibold">{value}</p>
      <p className="text-[10px] text-muted-foreground/70">{hint}</p>
    </div>
  );
}

void MetaPill;
