import { ArrowLeft, RefreshCw, Search, Trash2 } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { clearDocumentIndex, deleteDocument, reindexDocument, setDocumentRetrievalMode } from "../../core/documents";
import { humanBytes } from "../../core/capabilities";
import { useLiveValue } from "../../core/live";
import { db } from "../../db/db";
import { useToast } from "../../components/Toast";

export function DocumentPage() {
  const { documentId = "" } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const document = useLiveValue(() => db.documents.get(documentId), undefined, [documentId]);
  const chunks = useLiveValue(() => db.documentChunks.where("documentId").equals(documentId).sortBy("index"), [], [documentId]);
  const [query, setQuery] = useState("");
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState("");
  const filtered = useMemo(() => chunks.filter((chunk) => chunk.content.toLowerCase().includes(query.toLowerCase())), [chunks, query]);

  const indexBytes = chunks.reduce((sum, chunk) => sum + chunk.content.length * 2 + (chunk.embedding?.length ?? 0) * 8, 0);

  if (!document) return <section className="page"><div className="empty-state"><h2>Document not found</h2><Link to="/knowledge">Back to Knowledge</Link></div></section>;

  return (
    <section className="page">
      <header className="page-header">
        <div>
          <Link to="/knowledge" className="back-link"><ArrowLeft size={15} /> Knowledge</Link>
          <h1 className="document-title">{document.name}</h1>
          <p>{humanBytes(document.size)} · {document.chunkCount} chunks · {document.pageCount ?? "text"} {typeof document.pageCount === "number" ? "pages" : ""}</p>
        </div>
        <div className="header-tools">
          <select className="filter-select" value={document.retrievalMode} disabled={busy} onChange={async (event) => {
            setBusy(true);
            setProgress("Updating retrieval mode");
            try {
              await setDocumentRetrievalMode(document.id, event.target.value as "keyword" | "semantic" | "hybrid", (_value, label) => setProgress(label));
              toast.push("Retrieval mode updated", "success");
            } catch (error) {
              toast.push(error instanceof Error ? error.message : "Could not change retrieval mode", "error");
            } finally {
              setBusy(false);
              setProgress("");
            }
          }} aria-label="Document retrieval mode">
            <option value="keyword">Keyword</option>
            <option value="semantic">Semantic</option>
            <option value="hybrid">Hybrid</option>
          </select>
          <button className="soft-button" disabled={busy} onClick={async () => {
            setBusy(true);
            try {
              await reindexDocument(document.id, document.retrievalMode !== "keyword", (_value, label) => setProgress(label));
              toast.push("Document re-indexed", "success");
            } catch (error) {
              toast.push(error instanceof Error ? error.message : "Re-index failed", "error");
            } finally {
              setBusy(false);
              setProgress("");
            }
          }}><RefreshCw size={15} /> {busy ? (progress || "Working…") : "Re-index"}</button>
          <button className="soft-button" disabled={busy || chunks.length === 0} onClick={async () => {
            if (!window.confirm("Delete the local retrieval index but keep the original document source?")) return;
            await clearDocumentIndex(document.id);
            toast.push("Document source kept; retrieval index removed", "success");
          }}>Delete index only</button>
          <button className="soft-button danger-text" onClick={async () => {
            if (!window.confirm("Delete this source and index? Existing citations will keep tombstone metadata in chats.")) return;
            await deleteDocument(document.id);
            navigate("/knowledge");
          }}><Trash2 size={15} /> Delete</button>
        </div>
      </header>

      <div className="document-meta-grid">
        <div><span>Retrieval</span><strong>{document.retrievalMode}</strong></div>
        <div><span>Embedding model</span><strong>{document.embeddingModel ?? "None"}</strong></div>
        <div><span>SHA-256</span><strong className="mono">{document.sha256.slice(0, 16)}…</strong></div>
        <div><span>Index size</span><strong>{humanBytes(indexBytes)}</strong></div>
        <div><span>Indexed</span><strong>{document.indexedAt ? new Date(document.indexedAt).toLocaleString() : "Not indexed"}</strong></div>
      </div>

      <div className="search-box knowledge-search"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search extracted chunks" /></div>
      <div className="chunk-list">
        {filtered.map((chunk) => (
          <article className="chunk-card" key={chunk.id}>
            <div className="chunk-meta"><span>Chunk {chunk.index + 1}</span>{chunk.page && <span>Page {chunk.page}</span>}<span>{chunk.embedding?.length ? `${chunk.embedding.length}D vector` : "Lexical only"}</span></div>
            <p>{chunk.content}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
