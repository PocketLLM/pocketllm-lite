import { KeyRound, Plus, ShieldCheck, Trash2, Wifi } from "lucide-react";
import { useEffect, useState } from "react";
import { db } from "../../db/db";
import type { Provider, ProviderKind } from "../../core/types";

const emptyForm = { name: "Local Ollama", kind: "ollama" as ProviderKind, baseUrl: "http://127.0.0.1:11434", model: "", apiKey: "" };

export function SettingsPage() {
  const [providers, setProviders] = useState<Provider[]>([]);
  const [form, setForm] = useState(emptyForm);
  const [strictOffline, setStrictOffline] = useState(false);

  async function refresh() {
    setProviders(await db.providers.toArray());
    const strict = await db.settings.get("strictOffline");
    setStrictOffline(Boolean(strict?.value));
  }

  useEffect(() => { void refresh(); }, []);

  async function addProvider(event: React.FormEvent) {
    event.preventDefault();
    if (!form.name.trim() || !form.baseUrl.trim()) return;
    const now = Date.now();
    const id = crypto.randomUUID();
    await db.providers.add({
      id,
      name: form.name.trim(),
      kind: form.kind,
      baseUrl: form.baseUrl.trim(),
      model: form.model.trim(),
      createdAt: now,
      updatedAt: now,
    });
    if (form.apiKey) sessionStorage.setItem(`provider-key:${id}`, form.apiKey);
    setForm(emptyForm);
    await refresh();
  }

  async function removeProvider(id: string) {
    if (!window.confirm("Remove this provider? Stored chats are not deleted.")) return;
    sessionStorage.removeItem(`provider-key:${id}`);
    await db.providers.delete(id);
    await refresh();
  }

  async function toggleOffline() {
    const next = !strictOffline;
    await db.settings.put({ key: "strictOffline", value: next });
    setStrictOffline(next);
  }

  return (
    <section className="page settings-page">
      <header className="page-header"><div><p className="eyebrow">PocketLLM</p><h1>Settings</h1><p>Local state, explicit providers, visible boundaries.</p></div></header>

      <div className="settings-grid">
        <section className="settings-card">
          <div className="settings-title"><Wifi size={19} /><div><h2>Providers</h2><p>Keys are session-only in this first web implementation.</p></div></div>
          <form className="settings-form" onSubmit={addProvider}>
            <label>Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
            <label>Runtime<select value={form.kind} onChange={(e) => setForm({ ...form, kind: e.target.value as ProviderKind })}><option value="ollama">Ollama</option><option value="openai-compatible">OpenAI-compatible</option></select></label>
            <label>Base URL<input value={form.baseUrl} inputMode="url" onChange={(e) => setForm({ ...form, baseUrl: e.target.value })} /></label>
            <label>Model ID<input value={form.model} onChange={(e) => setForm({ ...form, model: e.target.value })} placeholder="e.g. qwen3:4b" /></label>
            {form.kind === "openai-compatible" && <label>API key <span className="hint">session only</span><div className="input-with-icon"><KeyRound size={16} /><input type="password" value={form.apiKey} onChange={(e) => setForm({ ...form, apiKey: e.target.value })} autoComplete="off" /></div></label>}
            <button className="primary-button" type="submit"><Plus size={17} /> Add provider</button>
          </form>
          <div className="provider-list">
            {providers.map((provider) => <div className="provider-list-row" key={provider.id}><div><strong>{provider.name}</strong><span>{provider.model || provider.baseUrl}</span></div><button className="icon-button danger" onClick={() => void removeProvider(provider.id)} aria-label={`Remove ${provider.name}`}><Trash2 size={16} /></button></div>)}
          </div>
        </section>

        <section className="settings-card">
          <div className="settings-title"><ShieldCheck size={19} /><div><h2>Privacy</h2><p>Network policy controls are being centralized as runtimes land.</p></div></div>
          <button className={`setting-toggle ${strictOffline ? "enabled" : ""}`} onClick={() => void toggleOffline()} aria-pressed={strictOffline}>
            <span><strong>Strict Offline</strong><small>Block remote runtimes when enforcement is fully wired.</small></span>
            <span className="switch"><span /></span>
          </button>
          <div className="notice">The toggle is persisted now, but enforcement is deliberately not claimed complete until every app-owned request is routed through the network gateway.</div>
        </section>
      </div>
    </section>
  );
}
