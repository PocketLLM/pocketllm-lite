import { BarChart3, BookOpenText, Bot, MessageSquareText } from "lucide-react";
import { useMemo } from "react";
import { useLiveValue } from "../../core/live";
import { db } from "../../db/db";

export function StatsPage() {
  const chats = useLiveValue(() => db.chats.toArray(), [], []);
  const messages = useLiveValue(() => db.messages.toArray(), [], []);
  const documents = useLiveValue(() => db.documents.toArray(), [], []);
  const usage = useLiveValue(() => db.usage.toArray(), [], []);

  const runtimeCounts = useMemo(() => {
    const map = new Map<string, number>();
    for (const event of usage.filter((item) => item.kind === "generation")) {
      const key = event.runtime ?? "unknown";
      map.set(key, (map.get(key) ?? 0) + (event.count ?? 1));
    }
    return [...map.entries()].sort((a, b) => b[1] - a[1]);
  }, [usage]);
  const generationCount = usage.filter((item) => item.kind === "generation").reduce((sum, item) => sum + (item.count ?? 1), 0);
  const thisMonth = new Date();
  const chatsThisMonth = chats.filter((chat) => {
    const date = new Date(chat.createdAt);
    return date.getFullYear() === thisMonth.getFullYear() && date.getMonth() === thisMonth.getMonth();
  }).length;

  return (
    <section className="page">
      <header className="page-header"><div><p className="eyebrow">Local-only metrics</p><h1>Statistics</h1><p>Usage counts never leave this browser unless you export them yourself.</p></div></header>
      <div className="stat-grid">
        <Stat icon={<MessageSquareText size={18} />} label="Chats this month" value={String(chatsThisMonth)} />
        <Stat icon={<Bot size={18} />} label="Generations" value={String(generationCount)} />
        <Stat icon={<BookOpenText size={18} />} label="Documents indexed" value={String(documents.length)} />
        <Stat icon={<BarChart3 size={18} />} label="Messages" value={String(messages.length)} />
      </div>
      <div className="settings-card stats-card">
        <div className="settings-title"><BarChart3 size={19} /><div><h2>Runtime usage</h2><p>Actual generation events recorded by PocketLLM Web.</p></div></div>
        <div className="runtime-bars">
          {runtimeCounts.length === 0 ? <p>No generations recorded yet.</p> : runtimeCounts.map(([runtime, count]) => {
            const max = runtimeCounts[0][1] || 1;
            return <div key={runtime}><div><strong>{runtime}</strong><span>{count}</span></div><progress max={max} value={count} /></div>;
          })}
        </div>
        <button className="soft-button danger-text" onClick={async () => { if (confirm("Clear usage statistics? Chats and documents will remain.")) await db.usage.clear(); }}>Clear statistics</button>
      </div>
    </section>
  );
}

function Stat({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return <div className="stat-card"><div className="stat-icon">{icon}</div><span>{label}</span><strong>{value}</strong></div>;
}
