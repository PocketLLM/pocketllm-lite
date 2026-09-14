import { AlertTriangle, Clock3, Trash2 } from "lucide-react";
import { useLiveValue } from "../../core/live";
import type { ActivityEntry, ErrorEntry } from "../../core/types";
import { db } from "../../db/db";

export function ActivityPage() {
  const rows = useLiveValue(() => db.activity.orderBy("timestamp").reverse().toArray(), [] as ActivityEntry[], []);
  return (
    <section className="page">
      <header className="page-header"><div><p className="eyebrow">Local audit trail</p><h1>Activity</h1><p>Product events only. Prompt bodies and private document contents are not recorded here.</p></div><button className="soft-button danger-text" onClick={async () => { if (confirm("Clear activity log?")) await db.activity.clear(); }}><Trash2 size={14} /> Clear</button></header>
      <div className="timeline">
        {rows.length === 0 ? <div className="empty-state list-card"><Clock3 size={26} /><h2>No activity yet</h2></div> :
          rows.map((item) => <article key={item.id}><span className="timeline-dot" /><div><strong>{item.title}</strong><span>{item.kind} · {new Date(item.timestamp).toLocaleString()}</span>{item.detail && <p>{item.detail}</p>}</div></article>)}
      </div>
    </section>
  );
}

export function ErrorLogPage() {
  const rows = useLiveValue(() => db.errors.orderBy("timestamp").reverse().toArray(), [] as ErrorEntry[], []);
  return (
    <section className="page">
      <header className="page-header"><div><p className="eyebrow">Diagnostics</p><h1>Error log</h1><p>Safe technical errors. Secrets, prompts and document text are intentionally excluded.</p></div><button className="soft-button danger-text" onClick={async () => { if (confirm("Clear error log?")) await db.errors.clear(); }}><Trash2 size={14} /> Clear</button></header>
      <div className="error-list">
        {rows.length === 0 ? <div className="empty-state list-card"><AlertTriangle size={25} /><h2>No recorded errors</h2></div> :
          rows.map((item) => <article key={item.id}><div className="error-head"><strong>{item.feature}</strong><span>{new Date(item.timestamp).toLocaleString()}</span></div><p>{item.safeMessage}</p>{item.runtime && <small>Runtime: {item.runtime}</small>}{item.stack && <details><summary>Stack</summary><pre>{item.stack}</pre></details>}</article>)}
      </div>
    </section>
  );
}
