import { FileText, Search, Trash2, Upload } from "lucide-react";
import { useEffect, useState } from "react";
import { db } from "../../db/db";
import type { KnowledgeDocument } from "../../core/types";

export function KnowledgePage() {
  const [documents, setDocuments] = useState<KnowledgeDocument[]>([]);
  const [busy, setBusy] = useState(false);

  async function refresh() {
    setDocuments(await db.documents.orderBy("updatedAt").reverse().toArray());
  }

  useEffect(() => { void refresh(); }, []);

  async function importFiles(files: FileList | null) {
    if (!files?.length) return;
    setBusy(true);
    try {
      for (const file of Array.from(files)) {
        const lower = file.name.toLowerCase();
        if (!lower.endsWith(".txt") && !lower.endsWith(".md") && !lower.endsWith(".csv")) {
          window.alert(`${file.name}: this first web build currently indexes TXT, Markdown and CSV. PDF parsing is coming in the next implementation pass.`);
          continue;
        }
        const text = await file.text();
        const now = Date.now();
        await db.documents.put({
          id: crypto.randomUUID(),
          name: file.name,
          mimeType: file.type || "text/plain",
          size: file.size,
          text,
          createdAt: now,
          updatedAt: now,
        });
      }
      await refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Local knowledge</p><h1>Knowledge</h1><p>Documents stay in this browser in this implementation.</p></div>
        <label className="primary-button file-button">
          <Upload size={17} /> {busy ? "Importing…" : "Import files"}
          <input type="file" multiple accept=".txt,.md,.csv,text/plain,text/markdown,text/csv" onChange={(event) => void importFiles(event.target.files)} />
        </label>
      </header>

      <div className="knowledge-grid">
        <div className="drop-card">
          <div className="drop-icon"><FileText size={25} /></div>
          <h2>Build a private reference library</h2>
          <p>Bring notes, Markdown and CSV data into PocketLLM. No upload account, no cloud library.</p>
        </div>
        <div className="list-card">
          {documents.length === 0 ? <div className="empty-state"><Search size={26} /><h2>No documents indexed</h2><p>Import a file to start your local knowledge base.</p></div> :
            documents.map((doc) => (
              <div className="history-row" key={doc.id}>
                <div className="history-main">
                  <strong>{doc.name}</strong>
                  <span>{(doc.size / 1024).toFixed(1)} KB · {doc.text.length.toLocaleString()} characters</span>
                </div>
                <button className="icon-button danger" aria-label={`Delete ${doc.name}`} onClick={async () => { if (window.confirm(`Delete ${doc.name}?`)) { await db.documents.delete(doc.id); await refresh(); } }}><Trash2 size={17} /></button>
              </div>
            ))}
        </div>
      </div>
    </section>
  );
}
