import { BarChart3, FlaskConical, Gauge, Play, Trash2 } from "lucide-react";
import { useMemo, useState } from "react";
import { useLiveValue } from "../../core/live";
import { chromeRuntime, providerRuntime, wllamaRuntime, type RuntimeAdapter } from "../../core/runtime";
import type { BrowserModel, LabRun, Provider, RuntimeKind } from "../../core/types";
import { estimateTokens } from "../../core/context";
import { db } from "../../db/db";
import { useToast } from "../../components/Toast";

type LabMode = "prompt" | "compare" | "benchmark";

function runtimeChoices(providers: Provider[], models: BrowserModel[]) {
  return [
    ...models.filter((item) => item.installed || item.runtime === "chrome-ai").map((item) => ({
      id: `model:${item.id}`,
      label: `${item.name} · Browser`,
      runtime: () => item.runtime === "chrome-ai" ? chromeRuntime() : wllamaRuntime(item),
    })),
    ...providers.map((provider) => ({
      id: `provider:${provider.id}`,
      label: `${provider.name} · ${provider.model || "model?"}`,
      runtime: () => providerRuntime(provider),
    })),
  ];
}

async function runAdapter(adapter: RuntimeAdapter, prompt: string, signal: AbortSignal, systemPrompt = "") {
  const startedAt = performance.now();
  let firstTokenAt: number | undefined;
  let output = "";
  await adapter.generate({
    messages: [
      ...(systemPrompt ? [{ role: "system" as const, content: systemPrompt }] : []),
      { role: "user", content: prompt },
    ],
    signal,
    maxTokens: 600,
    temperature: 0.4,
    topP: 0.9,
    topK: 40,
    onToken(token) {
      if (firstTokenAt === undefined) firstTokenAt = performance.now();
      output += token;
    },
  });
  const completedAt = performance.now();
  return {
    output,
    startedAt,
    firstTokenAt,
    completedAt,
    estimatedTokens: estimateTokens(output),
  };
}

export function LabPage({ mode }: { mode: LabMode }) {
  const providers = useLiveValue(() => db.providers.toArray(), [] as Provider[], []);
  const models = useLiveValue(() => db.browserModels.toArray(), [] as BrowserModel[], []);
  const runs = useLiveValue(() => db.labRuns.where("kind").equals(mode).reverse().sortBy("startedAt"), [] as LabRun[], [mode]);
  const toast = useToast();
  const choices = useMemo(() => runtimeChoices(providers, models), [providers, models]);
  const [prompt, setPrompt] = useState(mode === "benchmark" ? "Explain in 5 concise bullet points how a hash table works." : "");
  const [systemPrompt, setSystemPrompt] = useState("");
  const [selected, setSelected] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [liveResults, setLiveResults] = useState<Array<{ label: string; output: string; duration?: number; ttft?: number; tokensPerSecond?: number }>>([]);

  async function run() {
    const ids = mode === "compare" ? selected.slice(0, 4) : selected.slice(0, 1);
    if (!prompt.trim() || !ids.length) {
      toast.push("Choose a runtime and enter a prompt.", "error");
      return;
    }
    setBusy(true);
    setLiveResults(ids.map((id) => ({ label: choices.find((choice) => choice.id === id)?.label ?? id, output: "Running…" })));
    try {
      const jobs = ids.map(async (id, index) => {
        const choice = choices.find((item) => item.id === id);
        if (!choice) throw new Error("Runtime disappeared.");
        const adapter = choice.runtime();
        const controller = new AbortController();
        const result = await runAdapter(adapter, prompt, controller.signal, systemPrompt);
        const duration = (result.completedAt - result.startedAt) / 1000;
        const ttft = result.firstTokenAt === undefined ? undefined : (result.firstTokenAt - result.startedAt) / 1000;
        const tokensPerSecond = result.estimatedTokens && duration ? result.estimatedTokens / duration : undefined;
        const record: LabRun = {
          id: crypto.randomUUID(),
          kind: mode,
          prompt,
          model: adapter.modelName,
          runtime: adapter.id,
          output: result.output,
          startedAt: Date.now() - Math.round(duration * 1000),
          completedAt: Date.now(),
          firstTokenAt: ttft === undefined ? undefined : Date.now() - Math.round((duration - ttft) * 1000),
          outputCharacters: result.output.length,
          estimatedTokens: result.estimatedTokens,
        };
        await db.labRuns.add(record);
        setLiveResults((current) => current.map((item, currentIndex) => currentIndex === index ? { label: choice.label, output: result.output, duration, ttft, tokensPerSecond } : item));
      });
      if (mode === "compare") await Promise.all(jobs);
      else for (const job of jobs) await job;
    } catch (error) {
      toast.push(error instanceof Error ? error.message : "Lab run failed", "error");
    } finally {
      setBusy(false);
    }
  }

  const Icon = mode === "prompt" ? FlaskConical : mode === "compare" ? BarChart3 : Gauge;
  const title = mode === "prompt" ? "Prompt Lab" : mode === "compare" ? "Model comparison" : "Benchmark";
  const description = mode === "prompt"
    ? "Run a prompt in isolation, inspect timing and keep the result locally."
    : mode === "compare"
      ? "Send one prompt to up to four explicitly selected runtimes and compare actual outputs."
      : "Measure time-to-first-token and generation throughput on this device. Token counts are labeled estimated.";

  return (
    <section className="page">
      <header className="page-header"><div><p className="eyebrow">Engineering workspace</p><h1>{title}</h1><p>{description}</p></div></header>

      <div className="lab-layout">
        <section className="lab-controls settings-card">
          <div className="settings-title"><Icon size={19} /><div><h2>Run configuration</h2><p>No synthetic benchmark scores.</p></div></div>
          <div className="form-stack">
            {mode === "prompt" && <label>System layer <span className="hint">optional</span><textarea rows={4} value={systemPrompt} onChange={(e) => setSystemPrompt(e.target.value)} /></label>}
            <label>Prompt<textarea rows={8} value={prompt} onChange={(e) => setPrompt(e.target.value)} /></label>
            <fieldset className="runtime-picker">
              <legend>{mode === "compare" ? "Choose 2–4 runtimes" : "Choose runtime"}</legend>
              {choices.length === 0 ? <p>No runtime configured. Add a provider or browser model first.</p> : choices.map((choice) => {
                const checked = selected.includes(choice.id);
                return (
                  <label key={choice.id}>
                    <input
                      type={mode === "compare" ? "checkbox" : "radio"}
                      name="lab-runtime"
                      checked={checked}
                      onChange={(e) => {
                        if (mode === "compare") {
                          setSelected((current) => e.target.checked ? [...current.filter((id) => id !== choice.id), choice.id].slice(0, 4) : current.filter((id) => id !== choice.id));
                        } else {
                          setSelected([choice.id]);
                        }
                      }}
                    />
                    {choice.label}
                  </label>
                );
              })}
            </fieldset>
            <button className="primary-button" disabled={busy || !prompt.trim() || !selected.length} onClick={() => void run()}><Play size={15} /> {busy ? "Running…" : "Run"}</button>
          </div>
        </section>

        <section className="lab-results">
          {liveResults.length === 0 ? <div className="empty-state list-card"><Icon size={26} /><h2>No live result</h2><p>Run something worth comparing.</p></div> :
            liveResults.map((result) => (
              <article className="lab-result-card" key={result.label}>
                <div className="lab-result-head"><strong>{result.label}</strong>{result.duration !== undefined && <span>{result.duration.toFixed(2)} s</span>}</div>
                <pre>{result.output}</pre>
                {result.duration !== undefined && <div className="metric-row"><span>TTFT {result.ttft?.toFixed(2) ?? "—"} s</span><span>{result.tokensPerSecond?.toFixed(1) ?? "—"} est. tok/s</span></div>}
              </article>
            ))}
        </section>
      </div>

      <div className="section-heading"><h2>Saved runs</h2><button className="text-action danger-text" onClick={async () => { if (confirm("Clear saved runs for this lab?")) await db.labRuns.where("kind").equals(mode).delete(); }}><Trash2 size={13} /> Clear</button></div>
      <div className="lab-history">
        {runs.slice(0, 20).map((run) => {
          const duration = Math.max(0.001, (run.completedAt - run.startedAt) / 1000);
          return <article key={run.id}><div><strong>{run.model}</strong><span>{new Date(run.completedAt).toLocaleString()}</span></div><p>{run.prompt}</p><small>{duration.toFixed(2)} s · {run.estimatedTokens ?? "?"} estimated tokens</small></article>;
        })}
      </div>
    </section>
  );
}
