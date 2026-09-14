import { Bot, CheckCircle2, Cpu, ExternalLink } from "lucide-react";
import { useEffect, useState } from "react";
import { db } from "../../db/db";
import { runtimeFor } from "../../core/runtime";
import type { Provider } from "../../core/types";

export function ModelsPage() {
  const [providers, setProviders] = useState<Provider[]>([]);
  const [testing, setTesting] = useState<string>();
  const [results, setResults] = useState<Record<string, string>>({});

  async function refresh() { setProviders(await db.providers.toArray()); }
  useEffect(() => { void refresh(); }, []);

  async function test(provider: Provider) {
    setTesting(provider.id);
    setResults((old) => ({ ...old, [provider.id]: "" }));
    try {
      const key = sessionStorage.getItem(`provider-key:${provider.id}`) ?? undefined;
      const models = await runtimeFor(provider).test(provider, key);
      setResults((old) => ({ ...old, [provider.id]: models.length ? `Connected · ${models.length} model(s) visible` : "Connected · no models returned" }));
    } catch (error) {
      setResults((old) => ({ ...old, [provider.id]: error instanceof Error ? error.message : "Connection failed" }));
    } finally {
      setTesting(undefined);
    }
  }

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Inference</p><h1>Models & providers</h1><p>PocketLLM never guesses what a model can do. Connect only runtimes you control.</p></div>
      </header>

      <div className="model-grid">
        <article className="model-feature-card">
          <div className="model-icon"><Cpu size={22} /></div>
          <div><span className="eyebrow">Browser runtime</span><h2>On-device browser models</h2><p>WebGPU/WASM model execution is the next implementation stage. The UI does not pretend it is ready before the runtime lands.</p></div>
        </article>

        {providers.map((provider) => (
          <article className="provider-card" key={provider.id}>
            <div className="provider-heading"><div className="model-icon"><Bot size={20} /></div><div><strong>{provider.name}</strong><span>{provider.kind === "ollama" ? "Ollama" : "OpenAI-compatible"}</span></div></div>
            <dl><div><dt>Endpoint</dt><dd>{provider.baseUrl}</dd></div><div><dt>Model</dt><dd>{provider.model || "Not selected"}</dd></div></dl>
            {results[provider.id] && <p className="connection-result"><CheckCircle2 size={15} /> {results[provider.id]}</p>}
            <button className="soft-button" onClick={() => void test(provider)} disabled={testing === provider.id}>{testing === provider.id ? "Testing…" : "Test connection"} <ExternalLink size={14} /></button>
          </article>
        ))}
      </div>
    </section>
  );
}
