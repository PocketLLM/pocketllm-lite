import { CheckCircle2, KeyRound, Plus, TestTube2, Trash2, Wifi } from "lucide-react";
import { useState } from "react";
import { useLiveValue } from "../../core/live";
import { providerRuntime } from "../../core/runtime";
import type { Provider, ProviderKind, RuntimeCapabilities } from "../../core/types";
import { db } from "../../db/db";
import { useToast } from "../../components/Toast";
import { createOrReplaceVault, isVaultUnlocked, unlockVault, vaultGet, vaultSet } from "../../core/vault";

const defaultCapabilities: RuntimeCapabilities = { text: true, vision: false, embeddings: false, tools: false, audio: false };

export function ProvidersPage() {
  const providers = useLiveValue(() => db.providers.orderBy("updatedAt").reverse().toArray(), [] as Provider[], []);
  const toast = useToast();
  const [form, setForm] = useState({
    name: "Local Ollama",
    kind: "ollama" as ProviderKind,
    baseUrl: "http://127.0.0.1:11434",
    model: "",
    apiKey: "",
    rememberSecret: false,
    capabilities: { ...defaultCapabilities },
  });
  const [testing, setTesting] = useState<string>();
  const [results, setResults] = useState<Record<string, string>>({});

  async function add(event: React.FormEvent) {
    event.preventDefault();
    if (!form.name.trim() || !form.baseUrl.trim()) return;
    const now = Date.now();
    const id = crypto.randomUUID();
    const provider: Provider = {
      id,
      name: form.name.trim(),
      kind: form.kind,
      baseUrl: form.baseUrl.trim(),
      model: form.model.trim(),
      capabilities: { ...form.capabilities },
      rememberSecret: form.rememberSecret,
      createdAt: now,
      updatedAt: now,
    };
    await db.providers.add(provider);
    if (form.apiKey) {
      if (form.rememberSecret) {
        const passphrase = window.prompt("Vault passphrase (8+ characters). This passphrase is never stored.");
        if (!passphrase) {
          await db.providers.update(id, { rememberSecret: false });
          sessionStorage.setItem(`provider-key:${id}`, form.apiKey);
        } else {
          try {
            if (!isVaultUnlocked()) {
              const existing = await db.settings.get("encryptedVault");
              if (existing?.value) await unlockVault(passphrase);
              else await createOrReplaceVault(passphrase, {});
            }
            await vaultSet(`provider:${id}`, form.apiKey, passphrase);
            sessionStorage.setItem(`provider-key:${id}`, form.apiKey);
          } catch (error) {
            toast.push(error instanceof Error ? error.message : "Vault update failed", "error");
            sessionStorage.setItem(`provider-key:${id}`, form.apiKey);
            await db.providers.update(id, { rememberSecret: false });
          }
        }
      } else {
        sessionStorage.setItem(`provider-key:${id}`, form.apiKey);
      }
    }
    setForm({
      name: "Local Ollama",
      kind: "ollama",
      baseUrl: "http://127.0.0.1:11434",
      model: "",
      apiKey: "",
      rememberSecret: false,
      capabilities: { ...defaultCapabilities },
    });
    toast.push("Provider added", "success");
  }

  async function test(provider: Provider) {
    setTesting(provider.id);
    try {
      if (provider.rememberSecret && !sessionStorage.getItem(`provider-key:${provider.id}`)) {
        const passphrase = window.prompt("Unlock your local secret vault");
        if (passphrase) {
          await unlockVault(passphrase);
          const key = vaultGet(`provider:${provider.id}`);
          if (key) sessionStorage.setItem(`provider-key:${provider.id}`, key);
        }
      }
      const models = await providerRuntime(provider).test();
      setResults((old) => ({ ...old, [provider.id]: models.length ? `Connected · ${models.slice(0, 4).join(", ")}${models.length > 4 ? "…" : ""}` : "Connected · no models returned" }));
    } catch (error) {
      setResults((old) => ({ ...old, [provider.id]: error instanceof Error ? error.message : "Connection failed" }));
    } finally {
      setTesting(undefined);
    }
  }

  return (
    <section className="page">
      <header className="page-header"><div><p className="eyebrow">Inference endpoints</p><h1>Providers</h1><p>Ollama can run on this device or your LAN. OpenAI-compatible endpoints are explicit and capability-declared.</p></div></header>
      <div className="settings-grid">
        <section className="settings-card">
          <div className="settings-title"><Wifi size={19} /><div><h2>Add provider</h2><p>Nothing is auto-discovered on your LAN.</p></div></div>
          <form className="settings-form" onSubmit={add}>
            <label>Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
            <label>Runtime<select value={form.kind} onChange={(e) => {
              const kind = e.target.value as ProviderKind;
              setForm({ ...form, kind, baseUrl: kind === "ollama" ? "http://127.0.0.1:11434" : "https://api.example.com/v1" });
            }}><option value="ollama">Ollama</option><option value="openai-compatible">OpenAI-compatible</option></select></label>
            <label>Base URL<input value={form.baseUrl} inputMode="url" onChange={(e) => setForm({ ...form, baseUrl: e.target.value })} /></label>
            <label>Model ID<input value={form.model} onChange={(e) => setForm({ ...form, model: e.target.value })} placeholder={form.kind === "ollama" ? "qwen3:4b" : "your-model-id"} /></label>
            {form.kind === "openai-compatible" && (
              <>
                <label>API key<div className="input-with-icon"><KeyRound size={16} /><input type="password" value={form.apiKey} onChange={(e) => setForm({ ...form, apiKey: e.target.value })} autoComplete="off" /></div></label>
                <label className="check-line"><input type="checkbox" checked={form.rememberSecret} onChange={(e) => setForm({ ...form, rememberSecret: e.target.checked })} /> Remember encrypted in local vault</label>
              </>
            )}
            <fieldset className="capability-fieldset">
              <legend>Declared capabilities</legend>
              {(["text", "vision", "embeddings", "tools", "audio"] as const).map((key) => (
                <label key={key}><input type="checkbox" checked={form.capabilities[key]} disabled={key === "text"} onChange={(e) => setForm({ ...form, capabilities: { ...form.capabilities, [key]: e.target.checked } })} /> {key}</label>
              ))}
            </fieldset>
            <button className="primary-button" type="submit"><Plus size={17} /> Add provider</button>
          </form>
        </section>

        <section className="settings-card provider-manager">
          <div className="settings-title"><TestTube2 size={19} /><div><h2>Configured</h2><p>Connection checks never send your conversation.</p></div></div>
          {providers.length === 0 ? <div className="empty-state"><p>No providers configured.</p></div> : providers.map((provider) => (
            <div className="provider-list-row provider-detail-row" key={provider.id}>
              <div>
                <strong>{provider.name}</strong>
                <span>{provider.model || "No model selected"} · {provider.baseUrl}</span>
                {results[provider.id] && <small className={results[provider.id].startsWith("Connected") ? "good-text" : "danger-text"}>{results[provider.id]}</small>}
              </div>
              <div className="row-actions">
                <button className="soft-button" disabled={testing === provider.id} onClick={() => void test(provider)}>{testing === provider.id ? "Testing…" : <><CheckCircle2 size={14} /> Test</>}</button>
                <button className="icon-button danger" onClick={async () => {
                  if (!window.confirm(`Remove ${provider.name}? Chats stay local but will need another runtime.`)) return;
                  sessionStorage.removeItem(`provider-key:${provider.id}`);
                  await db.providers.delete(provider.id);
                }} aria-label={`Remove ${provider.name}`}><Trash2 size={16} /></button>
              </div>
            </div>
          ))}
        </section>
      </div>
    </section>
  );
}
