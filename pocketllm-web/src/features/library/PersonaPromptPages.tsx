import { Plus, Search, Trash2 } from "lucide-react";
import { useMemo, useState } from "react";
import { Modal } from "../../components/Modal";
import { useLiveValue } from "../../core/live";
import type { Persona, Prompt } from "../../core/types";
import { db } from "../../db/db";

export function PersonasPage() {
  const rows = useLiveValue(() => db.personas.orderBy("updatedAt").reverse().toArray(), [] as Persona[], []);
  const [query, setQuery] = useState("");
  const [editing, setEditing] = useState<Persona | null>(null);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ name: "", systemPrompt: "", temperature: 0.7, avatarIcon: "✦", modelId: "" });
  const filtered = useMemo(() => rows.filter((item) => [item.name, item.systemPrompt].join(" ").toLowerCase().includes(query.toLowerCase())), [rows, query]);

  function openCreate() {
    setForm({ name: "", systemPrompt: "", temperature: 0.7, avatarIcon: "✦", modelId: "" });
    setCreating(true);
  }
  function openEdit(item: Persona) {
    setForm({ name: item.name, systemPrompt: item.systemPrompt, temperature: item.temperature, avatarIcon: item.avatarIcon, modelId: item.modelId ?? "" });
    setEditing(item);
  }
  async function save() {
    if (!form.name.trim() || !form.systemPrompt.trim()) return;
    const now = Date.now();
    if (editing) {
      await db.personas.update(editing.id, { ...form, modelId: form.modelId || undefined, updatedAt: now });
      setEditing(null);
    } else {
      await db.personas.add({ id: crypto.randomUUID(), ...form, modelId: form.modelId || undefined, createdAt: now, updatedAt: now });
      setCreating(false);
    }
  }

  return (
    <section className="page">
      <ManagerHeader eyebrow="Prompt composition" title="Personas" description="Reusable behavior layers with their own temperature and optional preferred model." query={query} setQuery={setQuery} onCreate={openCreate} createLabel="New persona" />
      <div className="library-grid">
        {filtered.map((item) => (
          <article className="library-card" key={item.id}>
            <div className="library-card-top"><span className="persona-avatar">{item.avatarIcon}</span><div><strong>{item.name}</strong><span>Temperature {item.temperature.toFixed(1)}{item.modelId ? ` · ${item.modelId}` : ""}</span></div></div>
            <p>{item.systemPrompt}</p>
            <div className="card-actions"><button className="soft-button" onClick={() => openEdit(item)}>Edit</button><button className="icon-button danger" onClick={async () => { if (confirm(`Delete ${item.name}?`)) await db.personas.delete(item.id); }}><Trash2 size={16} /></button></div>
          </article>
        ))}
        {filtered.length === 0 && <Empty text="No personas match your search." />}
      </div>
      <Modal open={creating || Boolean(editing)} title={editing ? "Edit persona" : "New persona"} onClose={() => { setEditing(null); setCreating(false); }}>
        <div className="form-stack">
          <label>Name<input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></label>
          <div className="two-fields"><label>Avatar<input value={form.avatarIcon} maxLength={4} onChange={(e) => setForm({ ...form, avatarIcon: e.target.value })} /></label><label>Temperature<input type="number" min="0" max="2" step="0.1" value={form.temperature} onChange={(e) => setForm({ ...form, temperature: Number(e.target.value) })} /></label></div>
          <label>Preferred model ID <span className="hint">optional</span><input value={form.modelId} onChange={(e) => setForm({ ...form, modelId: e.target.value })} /></label>
          <label>System prompt<textarea rows={9} value={form.systemPrompt} onChange={(e) => setForm({ ...form, systemPrompt: e.target.value })} /></label>
          <div className="modal-actions"><button className="soft-button" onClick={() => { setEditing(null); setCreating(false); }}>Cancel</button><button className="primary-button" onClick={() => void save()}>Save persona</button></div>
        </div>
      </Modal>
    </section>
  );
}

export function PromptsPage() {
  const rows = useLiveValue(() => db.prompts.orderBy("updatedAt").reverse().toArray(), [] as Prompt[], []);
  const [query, setQuery] = useState("");
  const [editing, setEditing] = useState<Prompt | null>(null);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ title: "", content: "" });
  const filtered = useMemo(() => rows.filter((item) => [item.title, item.content].join(" ").toLowerCase().includes(query.toLowerCase())), [rows, query]);

  function openCreate() {
    setForm({ title: "", content: "" });
    setCreating(true);
  }
  function openEdit(item: Prompt) {
    setForm({ title: item.title, content: item.content });
    setEditing(item);
  }
  async function save() {
    if (!form.title.trim() || !form.content.trim()) return;
    const now = Date.now();
    if (editing) {
      await db.prompts.update(editing.id, { ...form, updatedAt: now });
      setEditing(null);
    } else {
      await db.prompts.add({ id: crypto.randomUUID(), ...form, createdAt: now, updatedAt: now });
      setCreating(false);
    }
  }

  return (
    <section className="page">
      <ManagerHeader eyebrow="Reusable instructions" title="Prompts" description="System-level instructions you can attach to a conversation." query={query} setQuery={setQuery} onCreate={openCreate} createLabel="New prompt" />
      <div className="library-grid">
        {filtered.map((item) => (
          <article className="library-card" key={item.id}>
            <div><strong>{item.title}</strong><span className="library-subtitle">{new Date(item.updatedAt).toLocaleDateString()}</span></div>
            <p>{item.content}</p>
            <div className="card-actions"><button className="soft-button" onClick={() => openEdit(item)}>Edit</button><button className="icon-button danger" onClick={async () => { if (confirm(`Delete ${item.title}?`)) await db.prompts.delete(item.id); }}><Trash2 size={16} /></button></div>
          </article>
        ))}
        {filtered.length === 0 && <Empty text="No prompts match your search." />}
      </div>
      <Modal open={creating || Boolean(editing)} title={editing ? "Edit prompt" : "New prompt"} onClose={() => { setEditing(null); setCreating(false); }}>
        <div className="form-stack">
          <label>Title<input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></label>
          <label>Prompt<textarea rows={12} value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} /></label>
          <div className="modal-actions"><button className="soft-button" onClick={() => { setEditing(null); setCreating(false); }}>Cancel</button><button className="primary-button" onClick={() => void save()}>Save prompt</button></div>
        </div>
      </Modal>
    </section>
  );
}

function ManagerHeader({ eyebrow, title, description, query, setQuery, onCreate, createLabel }: {
  eyebrow: string;
  title: string;
  description: string;
  query: string;
  setQuery: (value: string) => void;
  onCreate: () => void;
  createLabel: string;
}) {
  return (
    <header className="page-header">
      <div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1><p>{description}</p></div>
      <div className="header-tools">
        <div className="search-box"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={`Search ${title.toLowerCase()}`} /></div>
        <button className="primary-button" onClick={onCreate}><Plus size={16} /> {createLabel}</button>
      </div>
    </header>
  );
}

function Empty({ text }: { text: string }) {
  return <div className="empty-state wide"><p>{text}</p></div>;
}
