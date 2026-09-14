import { FileText, Search, Trash2, Upload } from "lucide-react";
import { useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { deleteDocument, ingestDocument } from "../../core/documents";
import { useLiveValue } from "../../core/live";
import { humanBytes } from "../../core/capabilities";
import { db } from "../../db/db";
import { useToast } from "../../components/Toast";

export function KnowledgePage() {
  const documents = useLiveValue(() => db.documents.orderBy("updatedAt").reverse().toArray(), [], []);
  const toast = useToast();
  const inputRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState("");
  const [semantic, setSemantic] = useState(true);
  const [progress, setProgress] = useState<{ value: number; label: string; name: string } | null>(null);

  const filtered = useMemo(() => documents.filter((document) => document.name.toLowerCase().includes(query.toLowerCase())), [documents, query]);

  async function importFiles(files: File[]) {
    for (const file of files) {
      try {
        setProgress({ value: 0, label: "Starting", name: file.name });
        const document = await ingestDocument(file, {
          semantic,
          onProgress(value, label) {
            setProgress({ value, label, name: file.name });
          },
        });
        toast.push(`${document.name} indexed`, "success");
      } catch (error) {
        toast.push(error instanceof Error ? error.message : `Could not index ${file.name}`, "error");
      }
    }
    setProgress(null);
    if (inputRef.current) inputRef.current.value = "";
  }

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Local knowledge</p><h1>Knowledge</h1><p>PDF, TXT, Markdown and CSV are extracted and indexed locally.</p></div>
        <div className="header-tools">
          <label className="check-pill"><input type="checkbox" checked={semantic} onChange={(e) => setSemantic(e.target.checked)} /> Semantic embeddings</label>
          <button className="primary-button" onClick={() => inputRef.current?.click()}><Upload size={17} /> Import files</button>
          <input ref={inputRef} hidden type="file" multiple accept=".pdf,.txt,.md,.markdown,.csv,text/plain,text/markdown,text/csv,application/pdf" onChange={(event) => void importFiles(Array.from(event.target.files ?? []))} />
        </div>
      </header>

      {progress && (
        <div className="progress-card" aria-live="polite">
          <div><strong>{progress.name}</strong><span>{progress.label}</span></div>
          <progress max={1} value={progress.value} />
        </div>
      )}

      <div className="search-box knowledge-search"><Search size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search documents" aria-label="Search documents" /></div>

      <div className="knowledge-grid">
        <div className="drop-card" onDragOver={(event) => event.preventDefault()} onDrop={(event) => { event.preventDefault(); void importFiles(Array.from(event.dataTransfer.files)); }}>
          <div className="drop-icon"><FileText size={25} /></div>
          <h2>Drop your private reference material here</h2>
          <p>Source bytes are stored in browser-private file storage. Extracted text and retrieval chunks live in IndexedDB.</p>
        </div>

        <div className="list-card">
          {filtered.length === 0 ? <div className="empty-state"><Search size={26} /><h2>No documents indexed</h2><p>Import something useful. Scanned/image-only PDFs are rejected until OCR is explicitly enabled.</p></div> :
            filtered.map((document) => (
              <div className="history-row" key={document.id}>
                <Link className="history-main" to={`/knowledge/${document.id}`}>
                  <strong>{document.name}</strong>
                  <span>{humanBytes(document.size)} · {document.chunkCount} chunks · {document.retrievalMode}{document.pageCount ? ` · ${document.pageCount} pages` : ""}</span>
                </Link>
                <button className="icon-button danger" aria-label={`Delete ${document.name}`} onClick={async () => {
                  if (window.confirm(`Delete ${document.name} and its index?`)) await deleteDocument(document.id);
                }}><Trash2 size={17} /></button>
              </div>
            ))}
        </div>
      </div>
    </section>
  );
}
