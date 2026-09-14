import { Database, Download, Eraser, HardDrive, RefreshCw, ShieldCheck, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import { humanBytes } from "../../core/capabilities";
import { clearBucket, getStorageReport, requestPersistentStorage, resetPocketLLM, type StorageBucket } from "../../core/storage";
import { db } from "../../db/db";
import { useToast } from "../../components/Toast";
import { Link } from "react-router-dom";

type Report = Awaited<ReturnType<typeof getStorageReport>>;

export function StoragePage() {
  const [report, setReport] = useState<Report | null>(null);
  const [busy, setBusy] = useState(false);
  const toast = useToast();

  async function refresh() {
    setReport(await getStorageReport());
  }
  useEffect(() => { void refresh(); }, []);

  async function clean(bucket: StorageBucket) {
    setBusy(true);
    try {
      await clearBucket(bucket);
      if (bucket === "downloads") await db.downloads.clear();
      toast.push(`${bucket} storage cleared`, "success");
      await refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="page">
      <header className="page-header"><div><p className="eyebrow">Device data</p><h1>Data & storage</h1><p>Know exactly what is consuming browser storage and delete categories independently.</p></div><button className="soft-button" onClick={() => void refresh()}><RefreshCw size={14} /> Refresh</button></header>
      {report && (
        <>
          <div className="storage-hero">
            <HardDrive size={22} />
            <div><strong>{humanBytes(report.usage)} used</strong><span>{report.quota ? `${humanBytes(report.quota)} browser quota` : "Quota unavailable"}</span></div>
            <div className={`persistence-badge ${report.persistent ? "good" : ""}`}><ShieldCheck size={15} /> {report.persistent ? "Persistent storage granted" : "Best-effort storage"}</div>
            {!report.persistent && <button className="soft-button" onClick={async () => { const granted = await requestPersistentStorage(); toast.push(granted ? "Persistent storage granted" : "Browser did not grant persistent storage", granted ? "success" : "error"); await refresh(); }}>Request persistence</button>}
          </div>

          <div className="storage-grid">
            {report.buckets.map((bucket) => (
              <article key={bucket.name} className="storage-card">
                <div><span>{bucket.name}</span><strong>{humanBytes(bucket.bytes)}</strong></div>
                {["tmp","downloads"].includes(bucket.name) && <button className="soft-button" disabled={busy || bucket.bytes === 0} onClick={() => void clean(bucket.name)}><Eraser size={14} /> Clear</button>}
              </article>
            ))}
          </div>

          <div className="section-heading"><h2>Structured data</h2></div>
          <div className="data-actions">
            <DataRow label="Chats" value={report.structured.chats} onDelete={async () => {
              if (!confirm("Delete all chats and messages? Export a backup first if these matter.")) return;
              await db.transaction("rw", db.chats, db.messages, async () => { await db.messages.clear(); await db.chats.clear(); });
              await refresh();
            }} />
            <DataRow label="Documents" value={report.structured.documents} onDelete={async () => {
              if (!confirm("Delete all document metadata and indexes?")) return;
              await db.transaction("rw", db.documents, db.documentChunks, async () => { await db.documentChunks.clear(); await db.documents.clear(); });
              await clearBucket("documents");
              await refresh();
            }} />
            <DataRow label="Memories" value={report.structured.memories} onDelete={async () => { if (confirm("Delete all memories?")) { await db.memories.clear(); await refresh(); } }} />
            <DataRow label="Logs" value={report.structured.logs} onDelete={async () => { if (confirm("Clear activity, network and error logs?")) { await Promise.all([db.activity.clear(), db.networkAudit.clear(), db.errors.clear()]); await refresh(); } }} />
          </div>
        </>
      )}

      <div className="danger-zone">
        <div><span className="eyebrow">Danger zone</span><h2>Reset PocketLLM</h2><p>This deletes IndexedDB and every PocketLLM OPFS bucket for this origin. Browser-cleared site data cannot be recovered without a backup.</p></div>
        <div className="danger-zone-actions"><Link className="soft-button" to="/settings"><Download size={14} /> Export backup first</Link><button className="danger-button" onClick={async () => {
          const phrase = prompt('Type "DELETE POCKETLLM" to reset all local web data.');
          if (phrase !== "DELETE POCKETLLM") return;
          await resetPocketLLM();
          location.href = "/app/";
        }}><Trash2 size={15} /> Reset everything</button></div>
      </div>
    </section>
  );
}

function DataRow({ label, value, onDelete }: { label: string; value: number; onDelete: () => Promise<void> }) {
  return <div className="data-row"><div><Database size={16} /><strong>{label}</strong><span>{value.toLocaleString()}</span></div><button className="icon-button danger" onClick={() => void onDelete()} aria-label={`Delete all ${label}`}><Trash2 size={16} /></button></div>;
}
