import { Download, Pin, Plus, Search, ShieldAlert, ToggleLeft, ToggleRight, Trash2 } from "lucide-react";
import { useMemo, useState } from "react";
import { Modal } from "../../components/Modal";
import { useToast } from "../../components/Toast";
import { useLiveValue } from "../../core/live";
import { isSensitiveMemory, saveMemory } from "../../core/memory";
import { networkFetch } from "../../core/network";
import type { MemoryRecord, MemoryType, Note, Skill } from "../../core/types";
import { db, setting } from "../../db/db";

export function SkillsPage() {
  const rows = useLiveValue(() => db.skills.orderBy("updatedAt").reverse().toArray(), [] as Skill[], []);
  const toast = useToast();
  const [query, setQuery] = useState("");
  const [editing, setEditing] = useState<Skill | null>(null);
  const [creating, setCreating] = useState(false);
  const [githubUrl, setGithubUrl] = useState("");
  const [form, setForm] = useState({ id: "", title: "", description: "", body: "", githubUrl: "", isEnabled: true });
  const filtered = useMemo(() => rows.filter((item) => [item.title, item.description, item.body].join(" ").toLowerCase().includes(query.toLowerCase())), [rows, query]);

  function openCreate() {
    setForm({ id: "", title: "", description: "", body: "", githubUrl: "", isEnabled: true });
    setCreating(true);
  }
  function openEdit(item: Skill) {
    setForm({ id: item.id, title: item.title, description: item.description, body: item.body, githubUrl: item.githubUrl ?? "", isEnabled: item.isEnabled });
    setEditing(item);
  }
  async function save() {
    const id = form.id.trim().toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "");
    if (!id || !form.title.trim() || !form.body.trim()) return;
    const now = Date.now();
    if (editing) {
      if (editing.id !== id) await db.skills.delete(editing.id);
      await db.skills.put({ id, title: form.title.trim(), description: form.description.trim(), body: form.body, githubUrl: form.githubUrl || undefined, isEnabled: form.isEnabled, createdAt: editing.createdAt, updatedAt: now });
      setEditing(null);
    } else {
      await db.skills.put({ id, title: form.title.trim(), description: form.description.trim(), body: form.body, githubUrl: form.githubUrl || undefined, isEnabled: form.isEnabled, createdAt: now, updatedAt: now });
      setCreating(false);
    }
  }

  async function installFromUrl() {
    if (!(await setting("githubSkillsEnabled", false))) return toast.push("Enable GitHub skill installation in Settings first.", "error");
    if (!githubUrl.startsWith("https://")) return toast.push("Use an HTTPS raw GitHub URL.", "error");
    try {
      const response = await networkFetch(githubUrl, {}, "github-skill");
      if (!response.ok) throw new Error(`GitHub returned HTTP ${response.status}`);
      const body = await response.text();
      if (body.length > 200_000) throw new Error("Skill manifest is too large.");
      const title = body.match(/^#\s+(.+)$/m)?.[1]?.trim() ?? "Imported skill";
      const id = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 64) || crypto.randomUUID();
      const now = Date.now();
      await db.skills.put({ id, title, description: `Imported from ${new URL(githubUrl).hostname}`, body, githubUrl, isEnabled: true, createdAt: now, updatedAt: now });
      setGithubUrl("");
      toast.push("Skill installed", "success");
    } catch (error) {
      toast.push(error instanceof Error ? error.message : "Skill install failed", "error");
    }
  }

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Prompt capabilities</p><h1>Skills</h1><p>Local Markdown instructions that join prompt composition when enabled.</p></div>
        <div className="header-tools"><div className="search-box"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search skills" /></div><button className="primary-button" onClick={openCreate}><Plus size={16} /> New skill</button></div>
      </header>
      <div className="install-strip">
        <input value={githubUrl} onChange={(e) => setGithubUrl(e.target.value)} placeholder="https://raw.githubusercontent.com/.../SKILL.md" />
        <button className="soft-button" onClick={() => void installFromUrl()}><Download size={15} /> Install from GitHub</button>
      </div>
      <div className="library-grid">
        {filtered.map((item) => (
          <article className="library-card" key={item.id}>
            <div className="library-card-top">
              <div><strong>{item.title}</strong><span>{item.id}</span></div>
              <button className="icon-button" onClick={() => void db.skills.update(item.id, { isEnabled: !item.isEnabled, updatedAt: Date.now() })} aria-label={item.isEnabled ? "Disable skill" : "Enable skill"}>{item.isEnabled ? <ToggleRight size={21} /> : <ToggleLeft size={21} />}</button>
            </div>
            <p>{item.description || item.body.slice(0, 220)}</p>
            <div className="card-actions"><button className="soft-button" onClick={() => exportNotes([item], `${item.title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "note"}.md`)}>Export</button><button className="soft-button" onClick={() => openEdit(item)}>Edit</button><button className="icon-button danger" onClick={async () => { if (confirm(`Delete ${item.title}?`)) await db.skills.delete(item.id); }}><Trash2 size={16} /></button></div>
          </article>
        ))}
      </div>
      <Modal open={creating || Boolean(editing)} title={editing ? "Edit skill" : "New skill"} onClose={() => { setCreating(false); setEditing(null); }}>
        <div className="form-stack">
          <label>Skill ID<input value={form.id} onChange={(e) => setForm({ ...form, id: e.target.value })} placeholder="web-design" /></label>
          <label>Title<input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></label>
          <label>Description<textarea rows={3} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></label>
          <label>Instructions<textarea rows={12} value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} /></label>
          <label className="check-line"><input type="checkbox" checked={form.isEnabled} onChange={(e) => setForm({ ...form, isEnabled: e.target.checked })} /> Enabled</label>
          <div className="modal-actions"><button className="soft-button" onClick={() => { setCreating(false); setEditing(null); }}>Cancel</button><button className="primary-button" onClick={() => void save()}>Save skill</button></div>
        </div>
      </Modal>
    </section>
  );
}

export function MemoriesPage() {
  const rows = useLiveValue(() => db.memories.orderBy("updatedAt").reverse().toArray(), [] as MemoryRecord[], []);
  const toast = useToast();
  const [query, setQuery] = useState("");
  const [view, setView] = useState<"active" | "pinned" | "recent" | "disabled" | "superseded">("active");
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState<MemoryRecord | null>(null);
  const [form, setForm] = useState<{ type: MemoryType; subject: string; fact: string }>({ type: "personalFact", subject: "user", fact: "" });

  const filtered = useMemo(() => {
    const recentCutoff = Date.now() - 30 * 24 * 60 * 60 * 1000;
    return rows.filter((item) => {
      if (![item.subject, item.fact, item.type].join(" ").toLowerCase().includes(query.toLowerCase())) return false;
      if (view === "active") return !item.supersededAt && item.enabled;
      if (view === "pinned") return !item.supersededAt && item.pinned;
      if (view === "recent") return !item.supersededAt && Boolean(item.lastUsedAt && item.lastUsedAt >= recentCutoff);
      if (view === "disabled") return !item.supersededAt && !item.enabled;
      return Boolean(item.supersededAt);
    });
  }, [rows, query, view]);

  function openCreate() {
    setEditing(null);
    setForm({ type: "personalFact", subject: "user", fact: "" });
    setCreating(true);
  }

  function openEdit(item: MemoryRecord) {
    setCreating(false);
    setEditing(item);
    setForm({ type: item.type, subject: item.subject, fact: item.fact });
  }

  async function save() {
    if (!form.fact.trim()) return;
    if (isSensitiveMemory(form.fact)) {
      toast.push("PocketLLM will not save secrets, card numbers, private keys or similar sensitive memory.", "error");
      return;
    }
    const now = Date.now();
    const target = editing;
    await saveMemory({
      id: target?.id ?? crypto.randomUUID(),
      type: form.type,
      subject: form.subject.trim() || "user",
      fact: form.fact.trim(),
      confidence: target?.confidence ?? 1,
      sourceMessageId: target?.sourceMessageId,
      sensitive: false,
      pinned: target?.pinned ?? false,
      enabled: target?.enabled ?? true,
      createdAt: target?.createdAt ?? now,
      lastUsedAt: target?.lastUsedAt,
      memoryKey: target?.memoryKey,
    });
    setForm({ type: "personalFact", subject: "user", fact: "" });
    setCreating(false);
    setEditing(null);
    toast.push(target ? "Memory updated" : "Memory saved", "success");
  }

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Local memory</p><h1>Memories</h1><p>Review exactly what PocketLLM may reuse. Sensitive automatic memories are rejected.</p></div>
        <div className="header-tools">
          <div className="search-box"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search memories" /></div>
          <select className="filter-select" value={view} onChange={(e) => setView(e.target.value as typeof view)} aria-label="Memory view">
            <option value="active">Active</option>
            <option value="pinned">Pinned</option>
            <option value="recent">Used recently</option>
            <option value="disabled">Disabled</option>
            <option value="superseded">Superseded</option>
          </select>
          <button className="primary-button" onClick={openCreate}><Plus size={16} /> Add memory</button>
        </div>
      </header>

      <div className="memory-list">
        {filtered.map((item) => (
          <article className={`memory-row ${item.enabled ? "" : "disabled"}`} key={item.id}>
            <div className="memory-main">
              <div className="memory-meta"><span>{item.type}</span><span>{item.subject}</span>{item.pinned && <span>pinned</span>}{item.supersededAt && <span>superseded</span>}</div>
              <p>{item.fact}</p>
              <small>
                Confidence {(item.confidence * 100).toFixed(0)}% · updated {new Date(item.updatedAt).toLocaleString()}
                {item.lastUsedAt ? ` · last used ${new Date(item.lastUsedAt).toLocaleString()}` : ""}
              </small>
            </div>
            <div className="row-actions">
              <button className="soft-button" onClick={() => openEdit(item)}>Edit</button>
              <button className="icon-button" onClick={() => void db.memories.update(item.id, { pinned: !item.pinned, updatedAt: Date.now() })} aria-label={item.pinned ? "Unpin memory" : "Pin memory"}><Pin size={16} fill={item.pinned ? "currentColor" : "none"} /></button>
              <button className="icon-button" onClick={() => void db.memories.update(item.id, { enabled: !item.enabled, updatedAt: Date.now() })} aria-label={item.enabled ? "Disable memory" : "Enable memory"}>{item.enabled ? <ToggleRight size={20} /> : <ToggleLeft size={20} />}</button>
              <button className="icon-button danger" onClick={async () => { if (confirm("Delete this memory?")) await db.memories.delete(item.id); }}><Trash2 size={16} /></button>
            </div>
          </article>
        ))}
        {filtered.length === 0 && <div className="empty-state"><ShieldAlert size={26} /><h2>No matching memories</h2><p>Automatic extraction is opt-in from Settings, and each conversation can disable memory saving.</p></div>}
      </div>

      <Modal open={creating || Boolean(editing)} title={editing ? "Edit memory" : "Add memory"} onClose={() => { setCreating(false); setEditing(null); }}>
        <div className="form-stack">
          <label>Type<select value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value as MemoryType })}>{["personalFact","preference","project","people","goal","writingStyle","reusableInstruction"].map((value) => <option value={value} key={value}>{value}</option>)}</select></label>
          <label>Subject<input value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} /></label>
          <label>Fact<textarea rows={6} value={form.fact} onChange={(e) => setForm({ ...form, fact: e.target.value })} /></label>
          <div className="modal-actions"><button className="soft-button" onClick={() => { setCreating(false); setEditing(null); }}>Cancel</button><button className="primary-button" onClick={() => void save()}>{editing ? "Update memory" : "Save memory"}</button></div>
        </div>
      </Modal>
    </section>
  );
}

export function NotesPage() {
  const rows = useLiveValue(() => db.notes.orderBy("updatedAt").reverse().toArray(), [] as Note[], []);
  const [query, setQuery] = useState("");
  const [editing, setEditing] = useState<Note | null>(null);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ title: "", content: "" });
  const filtered = useMemo(() => rows.filter((item) => [item.title, item.content].join(" ").toLowerCase().includes(query.toLowerCase())), [rows, query]);

  function exportNotes(items: Note[], name = "pocketllm-notes.md") {
    const markdown = items.map((item) => `# ${item.title}\n\n${item.content}\n`).join("\n");
    const blob = new Blob([markdown], { type: "text/markdown" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = name;
    link.click();
    URL.revokeObjectURL(url);
  }

  function openCreate() {
    setForm({ title: "", content: "" });
    setCreating(true);
  }
  function openEdit(item: Note) {
    setForm({ title: item.title, content: item.content });
    setEditing(item);
  }
  async function save() {
    if (!form.title.trim()) return;
    const now = Date.now();
    if (editing) {
      await db.notes.update(editing.id, { ...form, updatedAt: now });
      setEditing(null);
    } else {
      await db.notes.add({ id: crypto.randomUUID(), ...form, pinned: false, createdAt: now, updatedAt: now });
      setCreating(false);
    }
  }

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Local scratchpad</p><h1>Notes</h1><p>Tool-created notes and your own notes live together here.</p></div>
        <div className="header-tools"><div className="search-box"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search notes" /></div><button className="soft-button" disabled={!filtered.length} onClick={() => exportNotes(filtered)}><Download size={15} /> Export visible</button><button className="primary-button" onClick={openCreate}><Plus size={16} /> New note</button></div>
      </header>
      <div className="notes-grid">
        {filtered.map((item) => (
          <article className={`note-card ${item.pinned ? "pinned" : ""}`} key={item.id}>
            <div className="note-head"><strong>{item.title}</strong><button className="icon-button" onClick={() => void db.notes.update(item.id, { pinned: !item.pinned, updatedAt: Date.now() })}><Pin size={15} fill={item.pinned ? "currentColor" : "none"} /></button></div>
            <p>{item.content}</p>
            <div className="card-actions"><button className="soft-button" onClick={() => openEdit(item)}>Edit</button><button className="icon-button danger" onClick={async () => { if (confirm("Delete this note?")) await db.notes.delete(item.id); }}><Trash2 size={15} /></button></div>
          </article>
        ))}
      </div>
      <Modal open={creating || Boolean(editing)} title={editing ? "Edit note" : "New note"} onClose={() => { setCreating(false); setEditing(null); }}>
        <div className="form-stack">
          <label>Title<input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></label>
          <label>Content<textarea rows={14} value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} /></label>
          <div className="modal-actions"><button className="soft-button" onClick={() => { setCreating(false); setEditing(null); }}>Cancel</button><button className="primary-button" onClick={() => void save()}>Save note</button></div>
        </div>
      </Modal>
    </section>
  );
}
