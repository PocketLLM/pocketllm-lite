import { Filter, ShieldCheck, Trash2, Wifi, WifiOff } from "lucide-react";
import { useMemo, useState } from "react";
import { clearNetworkAudit } from "../../core/network";
import { useLiveValue } from "../../core/live";
import type { NetworkAudit, Provider } from "../../core/types";
import { db, saveSetting } from "../../db/db";

export function NetworkPage() {
  const logs = useLiveValue(() => db.networkAudit.orderBy("timestamp").reverse().toArray(), [] as NetworkAudit[], []);
  const providers = useLiveValue(() => db.providers.toArray(), [] as Provider[], []);
  const strictRow = useLiveValue(() => db.settings.get("strictOffline"), undefined, []);
  const strictOffline = Boolean(strictRow?.value);
  const [scope, setScope] = useState<"all" | NetworkAudit["scope"]>("all");
  const [status, setStatus] = useState<"all" | "allowed" | "blocked">("all");
  const [purpose, setPurpose] = useState("");
  const [destination, setDestination] = useState("");

  const purposes = useMemo(() => [...new Set(logs.map((item) => item.purpose))].sort(), [logs]);
  const filtered = useMemo(() => logs.filter((item) =>
    (scope === "all" || item.scope === scope) &&
    (status === "all" || (status === "allowed" ? item.allowed : !item.allowed)) &&
    (!purpose || item.purpose === purpose) &&
    (!destination.trim() || item.destination.toLowerCase().includes(destination.trim().toLowerCase()))
  ), [logs, scope, status, purpose, destination]);

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Privacy & transparency</p><h1>Network centre</h1><p>Every PocketLLM-owned request is classified and audited without storing prompt bodies.</p></div>
        <button className={`setting-toggle compact-toggle ${strictOffline ? "enabled" : ""}`} onClick={() => void saveSetting("strictOffline", !strictOffline)} aria-pressed={strictOffline}>
          <span><strong>Strict Offline</strong><small>{strictOffline ? "Internet and LAN blocked" : "Explicit network features allowed"}</small></span><span className="switch"><span /></span>
        </button>
      </header>

      <div className="network-summary">
        <div><ShieldCheck size={18} /><span><strong>{logs.filter((item) => item.allowed).length}</strong> allowed</span></div>
        <div><WifiOff size={18} /><span><strong>{logs.filter((item) => !item.allowed).length}</strong> blocked</span></div>
        <div><Wifi size={18} /><span><strong>{providers.length}</strong> configured endpoints</span></div>
      </div>

      <div className="filter-bar">
        <Filter size={16} />
        <select value={scope} onChange={(e) => setScope(e.target.value as any)}><option value="all">All scopes</option><option value="loopback">Loopback</option><option value="lan">LAN</option><option value="internet">Internet</option></select>
        <select value={status} onChange={(e) => setStatus(e.target.value as any)}><option value="all">All outcomes</option><option value="allowed">Allowed</option><option value="blocked">Blocked</option></select>
        <select value={purpose} onChange={(e) => setPurpose(e.target.value)} aria-label="Filter network purpose"><option value="">All features</option>{purposes.map((item) => <option value={item} key={item}>{item}</option>)}</select>
        <input className="network-filter-input" value={destination} onChange={(e) => setDestination(e.target.value)} placeholder="Destination" aria-label="Filter destination" />
        <button className="text-action danger-text" onClick={() => void clearNetworkAudit()}><Trash2 size={13} /> Clear log</button>
      </div>

      <div className="audit-list">
        {filtered.length === 0 ? <div className="empty-state list-card"><ShieldCheck size={28} /><h2>No matching network activity</h2><p>Requests appear here after PocketLLM performs them.</p></div> :
          filtered.map((item) => (
            <article className="audit-row" key={item.id}>
              <span className={`audit-state ${item.allowed ? "allowed" : "blocked"}`}>{item.allowed ? "Allowed" : "Blocked"}</span>
              <div className="audit-main"><strong>{item.destination}</strong><span>{item.purpose} · {item.scope}</span>{item.blockReason && <small>{item.blockReason}</small>}</div>
              <time>{new Date(item.timestamp).toLocaleString()}</time>
            </article>
          ))}
      </div>

      <div className="section-heading"><h2>Configured endpoints</h2></div>
      <div className="endpoint-list">
        {providers.map((provider) => <div className="endpoint-row" key={provider.id}><strong>{provider.name}</strong><span>{provider.baseUrl}</span><small>{provider.kind} · {provider.model || "model not selected"}</small></div>)}
      </div>
    </section>
  );
}
